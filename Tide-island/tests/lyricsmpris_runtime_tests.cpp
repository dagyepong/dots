#include <QCoreApplication>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QProcess>
#include <QTemporaryDir>
#include <QUrl>
#include <QtTest/QtTest>

#include <functional>

#include "ProviderNetworkPolicy.h"
#include <utility>

namespace {

constexpr auto kPlayerPath = "/org/mpris/MediaPlayer2";
constexpr auto kPlayerInterface = "org.mpris.MediaPlayer2.Player";
constexpr auto kPropertiesInterface = "org.freedesktop.DBus.Properties";

class FakeMprisPlayer final : public QObject {
    Q_OBJECT

public:
    explicit FakeMprisPlayer(QObject *parent = nullptr)
        : QObject(parent) {
    }

    QString playbackStatus() const { return QStringLiteral("Playing"); }
    QVariantMap metadata() const { return m_metadata; }
    qlonglong position() const { return 0; }

    void setMetadata(QVariantMap metadata) {
        m_metadata = std::move(metadata);

        QVariantMap changedProperties;
        changedProperties.insert(QStringLiteral("Metadata"), m_metadata);

        QDBusMessage signal = QDBusMessage::createSignal(
            QString::fromLatin1(kPlayerPath),
            QString::fromLatin1(kPropertiesInterface),
            QStringLiteral("PropertiesChanged"));
        signal.setArguments({
            QString::fromLatin1(kPlayerInterface),
            changedProperties,
            QStringList()
        });
        QDBusConnection::sessionBus().send(signal);
    }

private:
    QVariantMap m_metadata;
};

class FakePlayerAdaptor final : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(qlonglong Position READ position)

public:
    explicit FakePlayerAdaptor(FakeMprisPlayer *player)
        : QDBusAbstractAdaptor(player), m_player(player) {
    }

    QString playbackStatus() const { return m_player->playbackStatus(); }
    QVariantMap metadata() const { return m_player->metadata(); }
    qlonglong position() const { return m_player->position(); }

private:
    FakeMprisPlayer *m_player;
};

class HelperProbe final {
public:
    HelperProbe() {
        QObject::connect(&m_process, &QProcess::readyReadStandardOutput, [&]() {
            consumeStdout();
        });
        QObject::connect(&m_process, &QProcess::readyReadStandardError, [&]() {
            m_stderr.append(m_process.readAllStandardError());
        });
    }

    ~HelperProbe() {
        stop();
    }

    bool start(const QString &serviceName) {
        const QString executable = qEnvironmentVariable("LYRICSMPRIS_TEST_EXECUTABLE");
        if (executable.isEmpty()) {
            m_stderr = "LYRICSMPRIS_TEST_EXECUTABLE is not set";
            return false;
        }

        m_process.setProgram(executable);
        m_process.setArguments({
            QStringLiteral("--pipe"),
            QStringLiteral("--providers"),
            QStringLiteral("none"),
            serviceName
        });
        m_process.start();
        return m_process.waitForStarted(2000);
    }

    void stop() {
        if (m_process.state() == QProcess::NotRunning) {
            consumeStdout();
            m_stderr.append(m_process.readAllStandardError());
            return;
        }

        m_process.terminate();
        if (!m_process.waitForFinished(1000)) {
            m_process.kill();
            m_process.waitForFinished(1000);
        }
        consumeStdout();
        m_stderr.append(m_process.readAllStandardError());
    }

    bool hasStatus(const QString &status) const {
        for (const QJsonObject &message : m_messages) {
            if (message.value(QStringLiteral("type")).toString() == QLatin1String("status")
                && message.value(QStringLiteral("status")).toString() == status) {
                return true;
            }
        }
        return false;
    }

    bool hasCompletedInitialAttempt() const {
        return hasStatus(QStringLiteral("not_found")) || hasStatus(QStringLiteral("retrying"));
    }

    bool hasSyncedLine(const QString &text) const {
        for (const QJsonObject &message : m_messages) {
            if (message.value(QStringLiteral("type")).toString() == QLatin1String("line")
                && message.value(QStringLiteral("text")).toString() == text
                && message.value(QStringLiteral("synced")).toBool()) {
                return true;
            }
        }
        return false;
    }

    QString diagnostics() const {
        return QStringLiteral("stdout:\n%1\nstderr:\n%2")
            .arg(QString::fromUtf8(m_stdout), QString::fromUtf8(m_stderr));
    }

private:
    void consumeStdout() {
        const QByteArray bytes = m_process.readAllStandardOutput();
        m_stdout.append(bytes);
        m_pendingStdout.append(bytes);

        qsizetype newline = -1;
        while ((newline = m_pendingStdout.indexOf('\n')) >= 0) {
            const QByteArray line = m_pendingStdout.left(newline).trimmed();
            m_pendingStdout.remove(0, newline + 1);
            if (line.isEmpty()) continue;

            const QJsonDocument document = QJsonDocument::fromJson(line);
            if (document.isObject()) m_messages.append(document.object());
        }
    }

    QProcess m_process;
    QByteArray m_stdout;
    QByteArray m_pendingStdout;
    QByteArray m_stderr;
    QList<QJsonObject> m_messages;
};

bool waitUntil(const std::function<bool()> &condition, int timeoutMs) {
    QElapsedTimer timer;
    timer.start();
    while (!condition() && timer.elapsed() < timeoutMs) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 25);
        QTest::qWait(10);
    }
    QCoreApplication::processEvents(QEventLoop::AllEvents, 25);
    return condition();
}

bool writeLyrics(const QString &path, const QString &text) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    return file.write(text.toUtf8()) == text.toUtf8().size();
}

} // namespace

class LyricsMprisRuntimeTests final : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void init();
    void cleanup();

    void reloadsInlineLyricsArrivingForSameTrack();
    void reloadsLocalLyricsWhenUrlArrivesForSameTrack();
    void retriesSameTrackAfterLocalLyricsAppear();
    void neteaseRequestsDoNotReuseCookies();

private:
    QVariantMap metadata(const QString &url = QString(), const QString &inlineLyrics = QString()) const;
    QString m_serviceName;
    FakeMprisPlayer *m_player = nullptr;
};

void LyricsMprisRuntimeTests::initTestCase() {
    QVERIFY2(qEnvironmentVariableIsSet("TIDE_ISLAND_RUNTIME_TEST_ISOLATED"),
             "Run this test through CTest/dbus-run-session; refusing to use the real session bus");
    QVERIFY2(QDBusConnection::sessionBus().isConnected(), "No isolated D-Bus session is available");
}

void LyricsMprisRuntimeTests::init() {
    static int serviceCounter = 0;
    m_serviceName = QStringLiteral("org.mpris.MediaPlayer2.tideislandruntime%1x%2")
        .arg(QCoreApplication::applicationPid())
        .arg(++serviceCounter);

    m_player = new FakeMprisPlayer;
    new FakePlayerAdaptor(m_player);

    QDBusConnection bus = QDBusConnection::sessionBus();
    QVERIFY2(bus.registerService(m_serviceName), qPrintable(bus.lastError().message()));
    QVERIFY2(bus.registerObject(
                 QString::fromLatin1(kPlayerPath),
                 m_player,
                 QDBusConnection::ExportAdaptors),
             qPrintable(bus.lastError().message()));
}

void LyricsMprisRuntimeTests::cleanup() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.unregisterObject(QString::fromLatin1(kPlayerPath));
    bus.unregisterService(m_serviceName);
    delete m_player;
    m_player = nullptr;
}

QVariantMap LyricsMprisRuntimeTests::metadata(const QString &url, const QString &inlineLyrics) const {
    QVariantMap value;
    value.insert(QStringLiteral("mpris:trackid"),
                 QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/tideisland/runtime/track"))));
    value.insert(QStringLiteral("mpris:length"), qlonglong(120000000));
    value.insert(QStringLiteral("xesam:title"), QStringLiteral("Runtime Track"));
    value.insert(QStringLiteral("xesam:artist"), QStringList({QStringLiteral("Runtime Artist")}));
    value.insert(QStringLiteral("xesam:album"), QStringLiteral("Runtime Album"));
    if (!url.isEmpty()) value.insert(QStringLiteral("xesam:url"), url);
    if (!inlineLyrics.isEmpty()) value.insert(QStringLiteral("xesam:asText"), inlineLyrics);
    return value;
}

void LyricsMprisRuntimeTests::reloadsInlineLyricsArrivingForSameTrack() {
    m_player->setMetadata(metadata());

    HelperProbe helper;
    QVERIFY2(helper.start(m_serviceName), qPrintable(helper.diagnostics()));
    QVERIFY2(waitUntil([&]() { return helper.hasCompletedInitialAttempt(); }, 3000),
             qPrintable(helper.diagnostics()));

    const QString lyric = QStringLiteral("late inline lyric");
    m_player->setMetadata(metadata(QString(), QStringLiteral("[00:00.00]") + lyric));

    QVERIFY2(waitUntil([&]() { return helper.hasSyncedLine(lyric); }, 4000),
             qPrintable(helper.diagnostics()));
}

void LyricsMprisRuntimeTests::reloadsLocalLyricsWhenUrlArrivesForSameTrack() {
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString mediaPath = directory.filePath(QStringLiteral("late-url.mp3"));
    const QString lyricPath = directory.filePath(QStringLiteral("late-url.lrc"));
    const QString lyric = QStringLiteral("late local lyric");
    QVERIFY(writeLyrics(lyricPath, QStringLiteral("[00:00.00]") + lyric));

    m_player->setMetadata(metadata());

    HelperProbe helper;
    QVERIFY2(helper.start(m_serviceName), qPrintable(helper.diagnostics()));
    QVERIFY2(waitUntil([&]() { return helper.hasCompletedInitialAttempt(); }, 3000),
             qPrintable(helper.diagnostics()));

    m_player->setMetadata(metadata(QUrl::fromLocalFile(mediaPath).toString()));

    QVERIFY2(waitUntil([&]() { return helper.hasSyncedLine(lyric); }, 4000),
             qPrintable(helper.diagnostics()));
}

void LyricsMprisRuntimeTests::retriesSameTrackAfterLocalLyricsAppear() {
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString mediaPath = directory.filePath(QStringLiteral("retry-track.mp3"));
    const QString lyricPath = directory.filePath(QStringLiteral("retry-track.lrc"));
    const QString lyric = QStringLiteral("retry found local lyric");

    m_player->setMetadata(metadata(QUrl::fromLocalFile(mediaPath).toString()));

    HelperProbe helper;
    QVERIFY2(helper.start(m_serviceName), qPrintable(helper.diagnostics()));
    QVERIFY2(waitUntil([&]() { return helper.hasStatus(QStringLiteral("retrying")); }, 4000),
             qPrintable(helper.diagnostics()));

    QVERIFY(writeLyrics(lyricPath, QStringLiteral("[00:00.00]") + lyric));

    QVERIFY2(waitUntil([&]() { return helper.hasSyncedLine(lyric); }, 5000),
             qPrintable(helper.diagnostics()));
}

void LyricsMprisRuntimeTests::neteaseRequestsDoNotReuseCookies() {
    QNetworkRequest request(QUrl(QStringLiteral("https://music.163.com/api/search/get")));
    lyricsmpris::applyProviderNetworkPolicy(request, QStringLiteral("netease"));

    QCOMPARE(request.attribute(QNetworkRequest::CookieLoadControlAttribute).toInt(),
             int(QNetworkRequest::Manual));
    QCOMPARE(request.attribute(QNetworkRequest::CookieSaveControlAttribute).toInt(),
             int(QNetworkRequest::Manual));
}

QTEST_MAIN(LyricsMprisRuntimeTests)
#include "lyricsmpris_runtime_tests.moc"
