package extworkspace

import (
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	mocks_wlclient "github.com/acarlton5/HypeShell/core/internal/mocks/wlclient"
)

func TestStateChanged_BothNil(t *testing.T) {
	assert.True(t, stateChanged(nil, nil))
}

func TestStateChanged_OneNil(t *testing.T) {
	s := &State{Groups: []*WorkspaceGroup{}}
	assert.True(t, stateChanged(s, nil))
	assert.True(t, stateChanged(nil, s))
}

func TestStateChanged_GroupCountDiffers(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{ID: "group-1"}}}
	b := &State{Groups: []*WorkspaceGroup{}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_GroupIDDiffers(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{}, Workspaces: []*Workspace{}}}}
	b := &State{Groups: []*WorkspaceGroup{{ID: "group-2", Outputs: []string{}, Workspaces: []*Workspace{}}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputCountDiffers(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{"eDP-1"}, Workspaces: []*Workspace{}}}}
	b := &State{Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{}, Workspaces: []*Workspace{}}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_OutputNameDiffers(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{"eDP-1"}, Workspaces: []*Workspace{}}}}
	b := &State{Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{"HDMI-A-1"}, Workspaces: []*Workspace{}}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_WorkspaceCountDiffers(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{
		ID:         "group-1",
		Outputs:    []string{},
		Workspaces: []*Workspace{{ID: "1", Name: "ws1"}},
	}}}
	b := &State{Groups: []*WorkspaceGroup{{
		ID:         "group-1",
		Outputs:    []string{},
		Workspaces: []*Workspace{},
	}}}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_WorkspaceFieldsDiffer(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{
		ID:      "group-1",
		Outputs: []string{},
		Workspaces: []*Workspace{{
			ID: "1", Name: "ws1", State: 0, Active: false, Urgent: false, Hidden: false,
		}},
	}}}
	b := &State{Groups: []*WorkspaceGroup{{
		ID:      "group-1",
		Outputs: []string{},
		Workspaces: []*Workspace{{
			ID: "2", Name: "ws1", State: 0, Active: false, Urgent: false, Hidden: false,
		}},
	}}}
	assert.True(t, stateChanged(a, b))

	b.Groups[0].Workspaces[0].ID = "1"
	b.Groups[0].Workspaces[0].Name = "ws2"
	assert.True(t, stateChanged(a, b))

	b.Groups[0].Workspaces[0].Name = "ws1"
	b.Groups[0].Workspaces[0].State = 1
	assert.True(t, stateChanged(a, b))

	b.Groups[0].Workspaces[0].State = 0
	b.Groups[0].Workspaces[0].Active = true
	assert.True(t, stateChanged(a, b))

	b.Groups[0].Workspaces[0].Active = false
	b.Groups[0].Workspaces[0].Urgent = true
	assert.True(t, stateChanged(a, b))

	b.Groups[0].Workspaces[0].Urgent = false
	b.Groups[0].Workspaces[0].Hidden = true
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_WorkspaceCoordinatesDiffer(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{
		ID:      "group-1",
		Outputs: []string{},
		Workspaces: []*Workspace{{
			ID: "1", Name: "ws1", Coordinates: []uint32{0, 0},
		}},
	}}}
	b := &State{Groups: []*WorkspaceGroup{{
		ID:      "group-1",
		Outputs: []string{},
		Workspaces: []*Workspace{{
			ID: "1", Name: "ws1", Coordinates: []uint32{1, 0},
		}},
	}}}
	assert.True(t, stateChanged(a, b))

	b.Groups[0].Workspaces[0].Coordinates = []uint32{0}
	assert.True(t, stateChanged(a, b))
}

func TestStateChanged_Equal(t *testing.T) {
	a := &State{Groups: []*WorkspaceGroup{{
		ID:      "group-1",
		Outputs: []string{"eDP-1", "HDMI-A-1"},
		Workspaces: []*Workspace{
			{ID: "1", Name: "ws1", Coordinates: []uint32{0, 0}, State: 1, Active: true},
			{ID: "2", Name: "ws2", Coordinates: []uint32{1, 0}, State: 0, Active: false},
		},
	}}}
	b := &State{Groups: []*WorkspaceGroup{{
		ID:      "group-1",
		Outputs: []string{"eDP-1", "HDMI-A-1"},
		Workspaces: []*Workspace{
			{ID: "1", Name: "ws1", Coordinates: []uint32{0, 0}, State: 1, Active: true},
			{ID: "2", Name: "ws2", Coordinates: []uint32{1, 0}, State: 0, Active: false},
		},
	}}}
	assert.False(t, stateChanged(a, b))
}

func TestManager_ConcurrentGetState(t *testing.T) {
	m := &Manager{
		state: &State{
			Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{"eDP-1"}}},
		},
	}

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				s := m.GetState()
				_ = s.Groups
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.stateMutex.Lock()
				m.state = &State{
					Groups: []*WorkspaceGroup{{ID: "group-1", Outputs: []string{"eDP-1"}}},
				}
				m.stateMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentSubscriberAccess(t *testing.T) {
	m := &Manager{
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}

	var wg sync.WaitGroup
	const goroutines = 20

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			subID := string(rune('a' + id))
			ch := m.Subscribe(subID)
			assert.NotNil(t, ch)
			time.Sleep(time.Millisecond)
			m.Unsubscribe(subID)
		}(i)
	}

	wg.Wait()
}

func TestManager_SyncmapGroupsConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 50

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := uint32(id)

			for j := 0; j < iterations; j++ {
				state := &workspaceGroupState{
					id:           key,
					outputIDs:    map[uint32]bool{1: true},
					workspaceIDs: []uint32{uint32(j)},
				}
				m.groups.Store(key, state)

				if loaded, ok := m.groups.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.groups.Range(func(k uint32, v *workspaceGroupState) bool {
					_ = v.id
					_ = v.outputIDs
					return true
				})
			}

			m.groups.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_SyncmapWorkspacesConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 50

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := uint32(id)

			for j := 0; j < iterations; j++ {
				state := &workspaceState{
					id:          key,
					workspaceID: "ws-1",
					name:        "workspace",
					state:       uint32(j % 4),
					coordinates: []uint32{uint32(j), 0},
				}
				m.workspaces.Store(key, state)

				if loaded, ok := m.workspaces.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.workspaces.Range(func(k uint32, v *workspaceState) bool {
					_ = v.name
					_ = v.state
					return true
				})
			}

			m.workspaces.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_SyncmapOutputNamesConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 50

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := uint32(id)

			for j := 0; j < iterations; j++ {
				m.outputNames.Store(key, "eDP-1")

				if loaded, ok := m.outputNames.Load(key); ok {
					assert.NotEmpty(t, loaded)
				}

				m.outputNames.Range(func(k uint32, v string) bool {
					_ = v
					return true
				})
			}

			m.outputNames.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_NotifySubscribersNonBlocking(t *testing.T) {
	m := &Manager{
		dirty: make(chan struct{}, 1),
	}

	for i := 0; i < 10; i++ {
		m.notifySubscribers()
	}

	assert.Len(t, m.dirty, 1)
}

func TestManager_PostQueueFull(t *testing.T) {
	m := &Manager{
		cmdq:     make(chan cmd, 2),
		stopChan: make(chan struct{}),
	}

	m.post(func() {})
	m.post(func() {})
	m.post(func() {})
	m.post(func() {})

	assert.Len(t, m.cmdq, 2)
}

func TestManager_GetStateNilState(t *testing.T) {
	m := &Manager{}

	s := m.GetState()
	assert.NotNil(t, s.Groups)
	assert.Empty(t, s.Groups)
}

func TestWorkspace_Fields(t *testing.T) {
	ws := Workspace{
		ID:          "ws-1",
		Name:        "workspace 1",
		Coordinates: []uint32{0, 0},
		State:       1,
		Active:      true,
		Urgent:      false,
		Hidden:      false,
	}

	assert.Equal(t, "ws-1", ws.ID)
	assert.Equal(t, "workspace 1", ws.Name)
	assert.True(t, ws.Active)
	assert.False(t, ws.Urgent)
	assert.False(t, ws.Hidden)
}

func TestWorkspaceGroup_Fields(t *testing.T) {
	group := WorkspaceGroup{
		ID:      "group-1",
		Outputs: []string{"eDP-1", "HDMI-A-1"},
		Workspaces: []*Workspace{
			{ID: "ws-1", Name: "workspace 1"},
		},
	}

	assert.Equal(t, "group-1", group.ID)
	assert.Len(t, group.Outputs, 2)
	assert.Len(t, group.Workspaces, 1)
}

func TestNewManager_GetRegistryError(t *testing.T) {
	mockDisplay := mocks_wlclient.NewMockWaylandDisplay(t)

	mockDisplay.EXPECT().Context().Return(nil)
	mockDisplay.EXPECT().GetRegistry().Return(nil, errors.New("failed to get registry"))

	_, err := NewManager(mockDisplay)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to get registry")
}
