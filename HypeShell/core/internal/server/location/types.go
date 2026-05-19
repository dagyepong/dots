package location

import (
	"sync"

	"github.com/acarlton5/HypeShell/core/internal/geolocation"
	"github.com/acarlton5/HypeShell/core/pkg/syncmap"
)

type State struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Manager struct {
	state      *State
	stateMutex sync.RWMutex

	client geolocation.Client

	stopChan chan struct{}
	sigWG    sync.WaitGroup

	subscribers  syncmap.Map[string, chan State]
	dirty        chan struct{}
	notifierWg   sync.WaitGroup
	lastNotified *State
}
