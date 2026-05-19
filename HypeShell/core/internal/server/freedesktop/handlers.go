package freedesktop

import (
	"fmt"
	"net"

	"github.com/acarlton5/HypeShell/core/internal/server/models"
	"github.com/acarlton5/HypeShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "freedesktop.getState":
		handleGetState(conn, req, manager)
	case "freedesktop.accounts.setIconFile":
		handleSetIconFile(conn, req, manager)
	case "freedesktop.accounts.setRealName":
		handleSetRealName(conn, req, manager)
	case "freedesktop.accounts.setEmail":
		handleSetEmail(conn, req, manager)
	case "freedesktop.accounts.setLanguage":
		handleSetLanguage(conn, req, manager)
	case "freedesktop.accounts.setLocation":
		handleSetLocation(conn, req, manager)
	case "freedesktop.accounts.getUserIconFile":
		handleGetUserIconFile(conn, req, manager)
	case "freedesktop.settings.getColorScheme":
		handleGetColorScheme(conn, req, manager)
	case "freedesktop.settings.setIconTheme":
		handleSetIconTheme(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleSetIconFile(conn net.Conn, req models.Request, manager *Manager) {
	iconPath, err := params.String(req.Params, "path")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetIconFile(iconPath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "icon file set"})
}

func handleSetRealName(conn net.Conn, req models.Request, manager *Manager) {
	name, err := params.String(req.Params, "name")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetRealName(name); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "real name set"})
}

func handleSetEmail(conn net.Conn, req models.Request, manager *Manager) {
	email, err := params.String(req.Params, "email")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetEmail(email); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "email set"})
}

func handleSetLanguage(conn net.Conn, req models.Request, manager *Manager) {
	language, err := params.String(req.Params, "language")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetLanguage(language); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "language set"})
}

func handleSetLocation(conn net.Conn, req models.Request, manager *Manager) {
	location, err := params.String(req.Params, "location")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetLocation(location); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "location set"})
}

func handleGetUserIconFile(conn net.Conn, req models.Request, manager *Manager) {
	username, err := params.String(req.Params, "username")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	iconFile, err := manager.GetUserIconFile(username)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Value: iconFile})
}

func handleGetColorScheme(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.updateSettingsState(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	state := manager.GetState()
	models.Respond(conn, req.ID, map[string]uint32{"colorScheme": state.Settings.ColorScheme})
}

func handleSetIconTheme(conn net.Conn, req models.Request, manager *Manager) {
	iconTheme, err := params.String(req.Params, "iconTheme")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetIconTheme(iconTheme); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "icon theme set"})
}
