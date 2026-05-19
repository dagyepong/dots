package brightness

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/acarlton5/HypeShell/core/internal/server/models"
	"github.com/acarlton5/HypeShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request, m *Manager) {
	switch req.Method {
	case "brightness.getState":
		handleGetState(conn, req, m)
	case "brightness.setBrightness":
		handleSetBrightness(conn, req, m)
	case "brightness.increment":
		handleIncrement(conn, req, m)
	case "brightness.decrement":
		handleDecrement(conn, req, m)
	case "brightness.rescan":
		handleRescan(conn, req, m)
	case "brightness.subscribe":
		handleSubscribe(conn, req, m)
	default:
		models.RespondError(conn, req.ID, "unknown method: "+req.Method)
	}
}

func handleGetState(conn net.Conn, req models.Request, m *Manager) {
	models.Respond(conn, req.ID, m.GetState())
}

func handleSetBrightness(conn net.Conn, req models.Request, m *Manager) {
	device, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	percent, err := params.Int(req.Params, "percent")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	exponential := params.BoolOpt(req.Params, "exponential", false)
	exponent := params.FloatOpt(req.Params, "exponent", 1.2)

	if err := m.SetBrightnessWithExponent(device, percent, exponential, exponent); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, m.GetState())
}

func handleIncrement(conn net.Conn, req models.Request, m *Manager) {
	device, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	step := params.IntOpt(req.Params, "step", 10)
	exponential := params.BoolOpt(req.Params, "exponential", false)
	exponent := params.FloatOpt(req.Params, "exponent", 1.2)

	if err := m.IncrementBrightnessWithExponent(device, step, exponential, exponent); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, m.GetState())
}

func handleDecrement(conn net.Conn, req models.Request, m *Manager) {
	device, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	step := params.IntOpt(req.Params, "step", 10)
	exponential := params.BoolOpt(req.Params, "exponential", false)
	exponent := params.FloatOpt(req.Params, "exponent", 1.2)

	if err := m.IncrementBrightnessWithExponent(device, -step, exponential, exponent); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, m.GetState())
}

func handleRescan(conn net.Conn, req models.Request, m *Manager) {
	m.Rescan()
	models.Respond(conn, req.ID, m.GetState())
}

func handleSubscribe(conn net.Conn, req models.Request, m *Manager) {
	clientID := fmt.Sprintf("brightness-%d", req.ID)

	ch := m.Subscribe(clientID)
	defer m.Unsubscribe(clientID)

	initialState := m.GetState()
	if err := json.NewEncoder(conn).Encode(models.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range ch {
		if err := json.NewEncoder(conn).Encode(models.Response[State]{
			ID:     req.ID,
			Result: &state,
		}); err != nil {
			return
		}
	}
}
