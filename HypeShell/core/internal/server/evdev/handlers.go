package evdev

import (
	"net"

	"github.com/acarlton5/HypeShell/core/internal/server/models"
)

func HandleRequest(conn net.Conn, req models.Request, m *Manager) {
	switch req.Method {
	case "evdev.getState":
		handleGetState(conn, req, m)
	default:
		models.RespondError(conn, req.ID, "unknown method: "+req.Method)
	}
}

func handleGetState(conn net.Conn, req models.Request, m *Manager) {
	models.Respond(conn, req.ID, m.GetState())
}
