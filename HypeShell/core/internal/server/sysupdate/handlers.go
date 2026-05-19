package sysupdate

import (
	"net"

	"github.com/acarlton5/HypeShell/core/internal/server/models"
	"github.com/acarlton5/HypeShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request, m *Manager) {
	switch req.Method {
	case "sysupdate.getState":
		models.Respond(conn, req.ID, m.GetState())
	case "sysupdate.refresh":
		force := params.BoolOpt(req.Params, "force", false)
		m.Refresh(RefreshOptions{Force: force})
		models.Respond(conn, req.ID, m.GetState())
	case "sysupdate.upgrade":
		handleUpgrade(conn, req, m)
	case "sysupdate.cancel":
		m.Cancel()
		models.Respond(conn, req.ID, m.GetState())
	case "sysupdate.acquire":
		m.Acquire()
		models.Respond(conn, req.ID, models.SuccessResult{Success: true})
	case "sysupdate.release":
		m.Release()
		models.Respond(conn, req.ID, models.SuccessResult{Success: true})
	case "sysupdate.setInterval":
		seconds, err := params.Int(req.Params, "seconds")
		if err != nil {
			models.RespondError(conn, req.ID, err.Error())
			return
		}
		m.SetInterval(seconds)
		models.Respond(conn, req.ID, m.GetState())
	default:
		models.RespondError(conn, req.ID, "unknown method: "+req.Method)
	}
}

func handleUpgrade(conn net.Conn, req models.Request, m *Manager) {
	opts := UpgradeOptions{
		IncludeFlatpak: params.BoolOpt(req.Params, "includeFlatpak", true),
		IncludeAUR:     params.BoolOpt(req.Params, "includeAUR", true),
		DryRun:         params.BoolOpt(req.Params, "dry", false),
		CustomCommand:  params.StringOpt(req.Params, "customCommand", ""),
		CustomTitle:    params.StringOpt(req.Params, "customTitle", ""),
		Terminal:       params.StringOpt(req.Params, "terminal", ""),
		Targets:        parseUpgradeTargets(req.Params),
		Password:       params.StringOpt(req.Params, "password", ""),
	}
	if err := m.Upgrade(opts); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, m.GetState())
}

func parseUpgradeTargets(reqParams map[string]any) []Package {
	raw, ok := reqParams["targets"].([]any)
	if !ok || len(raw) == 0 {
		return nil
	}

	out := make([]Package, 0, len(raw))
	for _, item := range raw {
		m, ok := item.(map[string]any)
		if !ok {
			continue
		}
		name, _ := m["name"].(string)
		backend, _ := m["backend"].(string)
		if name == "" && backend == "" {
			continue
		}
		repo, _ := m["repo"].(string)
		fromVersion, _ := m["fromVersion"].(string)
		toVersion, _ := m["toVersion"].(string)
		out = append(out, Package{
			Name:        name,
			Repo:        RepoKind(repo),
			Backend:     backend,
			FromVersion: fromVersion,
			ToVersion:   toVersion,
		})
	}
	return out
}
