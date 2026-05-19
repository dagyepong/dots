package themes

import (
	"fmt"
	"net"

	"github.com/acarlton5/HypeShell/core/internal/server/models"
)

func HandleRequest(conn net.Conn, req models.Request) {
	switch req.Method {
	case "themes.list":
		HandleList(conn, req)
	case "themes.listInstalled":
		HandleListInstalled(conn, req)
	case "themes.install":
		HandleInstall(conn, req)
	case "themes.uninstall":
		HandleUninstall(conn, req)
	case "themes.update":
		HandleUpdate(conn, req)
	case "themes.search":
		HandleSearch(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}
