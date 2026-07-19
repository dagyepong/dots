#include <QCoreApplication>
#include <QGuiApplication>
#include <QDebug>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "backend.hpp"

int main(int argc, char *argv[]) {
    bool ensureNiriShortcuts = false;
    for (int index = 1; index < argc; ++index)
        ensureNiriShortcuts = ensureNiriShortcuts || QString::fromLocal8Bit(argv[index]) == QStringLiteral("--ensure-niri-shortcuts");

    if (ensureNiriShortcuts) {
        QCoreApplication app(argc, argv);
        Backend backend;
        if (!backend.niriShortcutBindingsNeedApply())
            return 0;
        if (backend.ensureNiriShortcutBindings())
            return 0;
        qCritical().noquote() << backend.errorString();
        return 1;
    }

    QGuiApplication app(argc, argv);
    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.loadFromModule(QStringLiteral("TideIsland"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
