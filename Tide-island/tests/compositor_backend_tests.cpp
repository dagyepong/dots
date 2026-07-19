#include "CompositorBackend.h"

#include <QSignalSpy>
#include <QTest>

class CompositorBackendTests : public QObject {
    Q_OBJECT

private slots:
    void detectsNiriFromDesktopEnvironment();
    void desktopEnvironmentWinsOverInheritedNiriSocket();
    void detectsNiriFromSocketEnvironmentBeforeConnectionIsReady();
    void niriWorkspacesUseIdxAndOutput();
    void niriWorkspaceActivationUpdatesFocusedOutput();
};

void CompositorBackendTests::detectsNiriFromDesktopEnvironment()
{
    qunsetenv("TIDE_ISLAND_COMPOSITOR");
    qunsetenv("NIRI_SOCKET");
    qputenv("XDG_CURRENT_DESKTOP", "niri");

    CompositorBackend backend;
    QCOMPARE(backend.compositor(), QStringLiteral("niri"));
}

void CompositorBackendTests::desktopEnvironmentWinsOverInheritedNiriSocket()
{
    qunsetenv("TIDE_ISLAND_COMPOSITOR");
    qputenv("XDG_CURRENT_DESKTOP", "Hyprland");
    qputenv("NIRI_SOCKET", "/tmp/inherited-niri.sock");

    CompositorBackend backend;
    QCOMPARE(backend.compositor(), QStringLiteral("hyprland"));
}

void CompositorBackendTests::detectsNiriFromSocketEnvironmentBeforeConnectionIsReady()
{
    qunsetenv("TIDE_ISLAND_COMPOSITOR");
    qunsetenv("XDG_CURRENT_DESKTOP");
    qputenv("NIRI_SOCKET", "/tmp/tide-island-niri-not-ready.sock");

    CompositorBackend backend;
    QCOMPARE(backend.compositor(), QStringLiteral("niri"));
}

void CompositorBackendTests::niriWorkspacesUseIdxAndOutput()
{
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");
    qputenv("NIRI_SOCKET", "/tmp/tide-island-missing-niri.sock");

    CompositorBackend backend;
    QCOMPARE(backend.compositor(), QStringLiteral("niri"));

    const QByteArray event = R"JSON({
        "WorkspacesChanged": {
            "workspaces": [
                {"id": 987654321, "idx": 2, "output": "eDP-1", "is_active": true, "is_focused": true},
                {"id": 42, "idx": 2, "output": "HDMI-A-1", "is_active": true, "is_focused": false},
                {"id": 43, "idx": 5, "output": "eDP-1", "is_active": false, "is_focused": false}
            ]
        }
    })JSON";

    QVERIFY(backend.applyNiriEventJson(event));
    QCOMPARE(backend.activeWorkspaceIndexForOutput(QStringLiteral("eDP-1")), 2);
    QCOMPARE(backend.activeWorkspaceIndexForOutput(QStringLiteral("HDMI-A-1")), 2);
    QCOMPARE(backend.focusedOutputName(), QStringLiteral("eDP-1"));
    QVERIFY(backend.isOutputFocused(QStringLiteral("eDP-1")));
    QVERIFY(!backend.isOutputFocused(QStringLiteral("HDMI-A-1")));
}

void CompositorBackendTests::niriWorkspaceActivationUpdatesFocusedOutput()
{
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");
    qputenv("NIRI_SOCKET", "/tmp/tide-island-missing-niri.sock");

    CompositorBackend backend;
    QVERIFY(backend.applyNiriEventJson(R"JSON({
        "WorkspacesChanged": {
            "workspaces": [
                {"id": 11, "idx": 1, "output": "eDP-1", "is_active": true, "is_focused": true},
                {"id": 12, "idx": 3, "output": "eDP-1", "is_active": false, "is_focused": false},
                {"id": 21, "idx": 1, "output": "HDMI-A-1", "is_active": true, "is_focused": false},
                {"id": 22, "idx": 4, "output": "HDMI-A-1", "is_active": false, "is_focused": false}
            ]
        }
    })JSON"));

    QSignalSpy revisionSpy(&backend, &CompositorBackend::revisionChanged);
    QVERIFY(backend.applyNiriEventJson(R"JSON({"WorkspaceActivated": {"id": 12, "focused": true}})JSON"));
    QCOMPARE(backend.activeWorkspaceIndexForOutput(QStringLiteral("eDP-1")), 3);
    QCOMPARE(backend.activeWorkspaceIndexForOutput(QStringLiteral("HDMI-A-1")), 1);
    QCOMPARE(backend.focusedOutputName(), QStringLiteral("eDP-1"));
    QCOMPARE(revisionSpy.count(), 1);

    QVERIFY(backend.applyNiriEventJson(R"JSON({"WorkspaceActivated": {"id": 22, "focused": true}})JSON"));
    QCOMPARE(backend.activeWorkspaceIndexForOutput(QStringLiteral("HDMI-A-1")), 4);
    QCOMPARE(backend.focusedOutputName(), QStringLiteral("HDMI-A-1"));
    QVERIFY(backend.isOutputFocused(QStringLiteral("HDMI-A-1")));
    QVERIFY(!backend.isOutputFocused(QStringLiteral("eDP-1")));
}

QTEST_MAIN(CompositorBackendTests)

#include "compositor_backend_tests.moc"
