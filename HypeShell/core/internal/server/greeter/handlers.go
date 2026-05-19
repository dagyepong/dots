package greeter

import (
	"fmt"
	"net"

	shellgreeter "github.com/acarlton5/HypeShell/core/internal/greeter"
	"github.com/acarlton5/HypeShell/core/internal/server/models"
)

func HandleRequest(conn net.Conn, req models.Request) {
	switch req.Method {
	case "greeter.syncTheme":
		HandleSyncTheme(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func HandleSyncTheme(conn net.Conn, req models.Request) {
	if err := shellgreeter.SyncCurrentThemeCache(nil); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{
		Success: true,
		Message: "greeter theme cache synced",
	})
}
