package providers

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/acarlton5/HypeShell/core/internal/utils"
)

const (
	TitleRegex         = "#+!"
	HideComment        = "[hidden]"
	CommentBindPattern = "#/#"
)

var ModSeparators = []rune{'+', ' '}

type HyprlandKeyBinding struct {
	Mods       []string `json:"mods"`
	Key        string   `json:"key"`
	Dispatcher string   `json:"dispatcher"`
	Params     string   `json:"params"`
	Comment    string   `json:"comment"`
	Source     string   `json:"source"`
	Flags      string   `json:"flags"` // Bind flags: l=locked, r=release, e=repeat, n=non-consuming, m=mouse, t=transparent, i=ignore-mods, s=separate, d=description, o=long-press
}

type HyprlandSection struct {
	Children []HyprlandSection    `json:"children"`
	Keybinds []HyprlandKeyBinding `json:"keybinds"`
	Name     string               `json:"name"`
}

type HyprlandParser struct {
	contentLines       []string
	readingLine        int
	configDir          string
	currentSource      string
	hypeBindsExists     bool
	hypeBindsIncluded   bool
	includeCount       int
	hypeIncludePos      int
	bindsAfterHYPE      int
	hypeBindKeys        map[string]bool
	configBindKeys     map[string]bool
	conflictingConfigs map[string]*HyprlandKeyBinding
	bindMap            map[string]*HyprlandKeyBinding
	bindOrder          []string
	processedFiles     map[string]bool
	hypeProcessed       bool
}

func NewHyprlandParser(configDir string) *HyprlandParser {
	return &HyprlandParser{
		contentLines:       []string{},
		readingLine:        0,
		configDir:          configDir,
		hypeIncludePos:      -1,
		hypeBindKeys:        make(map[string]bool),
		configBindKeys:     make(map[string]bool),
		conflictingConfigs: make(map[string]*HyprlandKeyBinding),
		bindMap:            make(map[string]*HyprlandKeyBinding),
		bindOrder:          []string{},
		processedFiles:     make(map[string]bool),
	}
}

func (p *HyprlandParser) ReadContent(directory string) error {
	expandedDir, err := utils.ExpandPath(directory)
	if err != nil {
		return err
	}

	info, err := os.Stat(expandedDir)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return os.ErrNotExist
	}

	confFiles, err := filepath.Glob(filepath.Join(expandedDir, "*.conf"))
	if err != nil {
		return err
	}
	if len(confFiles) == 0 {
		return os.ErrNotExist
	}

	var combinedContent []string
	for _, confFile := range confFiles {
		if fileInfo, err := os.Stat(confFile); err == nil && fileInfo.Mode().IsRegular() {
			data, err := os.ReadFile(confFile)
			if err == nil {
				combinedContent = append(combinedContent, string(data))
			}
		}
	}

	if len(combinedContent) == 0 {
		return os.ErrNotExist
	}

	fullContent := strings.Join(combinedContent, "\n")
	p.contentLines = strings.Split(fullContent, "\n")
	return nil
}

func hyprlandAutogenerateComment(dispatcher, params string) string {
	switch dispatcher {
	case "resizewindow":
		return "Resize window"

	case "movewindow":
		if params == "" {
			return "Move window"
		}
		dirMap := map[string]string{
			"l": "left",
			"r": "right",
			"u": "up",
			"d": "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "move in " + dir + " direction"
		}
		return "move in null direction"

	case "pin":
		return "pin (show on all workspaces)"

	case "splitratio":
		return "Window split ratio " + params

	case "togglefloating":
		return "Float/unfloat window"

	case "resizeactive":
		return "Resize window by " + params

	case "killactive":
		return "Close window"

	case "fullscreen":
		fsMap := map[string]string{
			"0": "fullscreen",
			"1": "maximization",
			"2": "fullscreen on Hyprland's side",
		}
		if fs, ok := fsMap[params]; ok {
			return "Toggle " + fs
		}
		return "Toggle null"

	case "fakefullscreen":
		return "Toggle fake fullscreen"

	case "workspace":
		switch params {
		case "+1":
			return "focus right"
		case "-1":
			return "focus left"
		}
		return "focus workspace " + params
	case "movefocus":
		dirMap := map[string]string{
			"l": "left",
			"r": "right",
			"u": "up",
			"d": "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "move focus " + dir
		}
		return "move focus null"

	case "swapwindow":
		dirMap := map[string]string{
			"l": "left",
			"r": "right",
			"u": "up",
			"d": "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "swap in " + dir + " direction"
		}
		return "swap in null direction"

	case "movetoworkspace":
		switch params {
		case "+1":
			return "move to right workspace (non-silent)"
		case "-1":
			return "move to left workspace (non-silent)"
		}
		return "move to workspace " + params + " (non-silent)"
	case "movetoworkspacesilent":
		switch params {
		case "+1":
			return "move to right workspace"
		case "-1":
			return "move to right workspace"
		}
		return "move to workspace " + params

	case "togglespecialworkspace":
		return "toggle special"

	case "exec":
		return params

	default:
		return ""
	}
}

func (p *HyprlandParser) getKeybindAtLine(lineNumber int) *HyprlandKeyBinding {
	line := p.contentLines[lineNumber]
	return p.parseBindLine(line)
}

func (p *HyprlandParser) getBindsRecursive(currentContent *HyprlandSection, scope int) *HyprlandSection {
	titleRegex := regexp.MustCompile(TitleRegex)

	for p.readingLine < len(p.contentLines) {
		line := p.contentLines[p.readingLine]

		loc := titleRegex.FindStringIndex(line)
		if loc != nil && loc[0] == 0 {
			headingScope := strings.Index(line, "!")

			if headingScope <= scope {
				p.readingLine--
				return currentContent
			}

			sectionName := strings.TrimSpace(line[headingScope+1:])
			p.readingLine++

			childSection := &HyprlandSection{
				Children: []HyprlandSection{},
				Keybinds: []HyprlandKeyBinding{},
				Name:     sectionName,
			}
			result := p.getBindsRecursive(childSection, headingScope)
			currentContent.Children = append(currentContent.Children, *result)

		} else if strings.HasPrefix(line, CommentBindPattern) {
			keybind := p.getKeybindAtLine(p.readingLine)
			if keybind != nil {
				currentContent.Keybinds = append(currentContent.Keybinds, *keybind)
			}

		} else if line == "" || !strings.HasPrefix(strings.TrimSpace(line), "bind") {

		} else {
			keybind := p.getKeybindAtLine(p.readingLine)
			if keybind != nil {
				currentContent.Keybinds = append(currentContent.Keybinds, *keybind)
			}
		}

		p.readingLine++
	}

	return currentContent
}

func (p *HyprlandParser) ParseKeys() *HyprlandSection {
	p.readingLine = 0
	rootSection := &HyprlandSection{
		Children: []HyprlandSection{},
		Keybinds: []HyprlandKeyBinding{},
		Name:     "",
	}
	return p.getBindsRecursive(rootSection, 0)
}

func ParseHyprlandKeys(path string) (*HyprlandSection, error) {
	parser := NewHyprlandParser(path)
	if err := parser.ReadContent(path); err != nil {
		return nil, err
	}
	return parser.ParseKeys(), nil
}

type HyprlandParseResult struct {
	Section            *HyprlandSection
	HYPEBindsIncluded   bool
	HYPEStatus          *HyprlandHYPEStatus
	ConflictingConfigs map[string]*HyprlandKeyBinding
}

type HyprlandHYPEStatus struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	BindsAfterHYPE   int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
}

func (p *HyprlandParser) buildHYPEStatus() *HyprlandHYPEStatus {
	status := &HyprlandHYPEStatus{
		Exists:          p.hypeBindsExists,
		Included:        p.hypeBindsIncluded,
		IncludePosition: p.hypeIncludePos,
		TotalIncludes:   p.includeCount,
		BindsAfterHYPE:   p.bindsAfterHYPE,
	}

	switch {
	case !p.hypeBindsExists:
		status.Effective = false
		status.StatusMessage = "hype/binds.conf does not exist"
	case !p.hypeBindsIncluded:
		status.Effective = false
		status.StatusMessage = "hype/binds.conf is not sourced in config"
	case p.bindsAfterHYPE > 0:
		status.Effective = true
		status.OverriddenBy = p.bindsAfterHYPE
		status.StatusMessage = "Some HypeShell binds may be overridden by config binds"
	default:
		status.Effective = true
		status.StatusMessage = "HypeShell binds are active"
	}

	return status
}

func (p *HyprlandParser) formatBindKey(kb *HyprlandKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (p *HyprlandParser) normalizeKey(key string) string {
	return strings.ToLower(key)
}

func isHyprlandShellBindsPath(path string) bool {
	normalized := strings.ReplaceAll(path, "\\", "/")
	return strings.Contains(normalized, "hype/binds.conf") || strings.Contains(normalized, "hype/binds.conf")
}

func (p *HyprlandParser) addBind(kb *HyprlandKeyBinding) bool {
	key := p.formatBindKey(kb)
	normalizedKey := p.normalizeKey(key)
	isHYPEBind := isHyprlandShellBindsPath(kb.Source)

	if isHYPEBind {
		p.hypeBindKeys[normalizedKey] = true
	} else if p.hypeBindKeys[normalizedKey] {
		p.bindsAfterHYPE++
		p.conflictingConfigs[normalizedKey] = kb
		p.configBindKeys[normalizedKey] = true
		return false
	} else {
		p.configBindKeys[normalizedKey] = true
	}

	if _, exists := p.bindMap[normalizedKey]; !exists {
		p.bindOrder = append(p.bindOrder, key)
	}
	p.bindMap[normalizedKey] = kb
	return true
}

func (p *HyprlandParser) ParseWithHYPE() (*HyprlandSection, error) {
	expandedDir, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}

	hypeBindsPath := filepath.Join(expandedDir, "hype", "binds.conf")
	legacyBindsPath := filepath.Join(expandedDir, "hype", "binds.conf")
	if _, err := os.Stat(hypeBindsPath); err == nil {
		p.hypeBindsExists = true
	} else if _, err := os.Stat(legacyBindsPath); err == nil {
		hypeBindsPath = legacyBindsPath
		p.hypeBindsExists = true
	}

	mainConfig := filepath.Join(expandedDir, "hyprland.conf")
	section, err := p.parseFileWithSource(mainConfig, "")
	if err != nil {
		return nil, err
	}

	if p.hypeBindsExists && !p.hypeProcessed {
		p.parseHYPEBindsDirectly(hypeBindsPath, section)
	}

	return section, nil
}

func (p *HyprlandParser) parseFileWithSource(filePath, sectionName string) (*HyprlandSection, error) {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, err
	}

	if p.processedFiles[absPath] {
		return &HyprlandSection{Name: sectionName}, nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, err
	}

	prevSource := p.currentSource
	p.currentSource = absPath

	section := &HyprlandSection{Name: sectionName}
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "source") {
			p.handleSource(trimmed, section, filepath.Dir(absPath))
			continue
		}

		if !strings.HasPrefix(trimmed, "bind") {
			continue
		}

		kb := p.parseBindLine(line)
		if kb == nil {
			continue
		}
		kb.Source = p.currentSource
		if p.addBind(kb) {
			section.Keybinds = append(section.Keybinds, *kb)
		}
	}

	p.currentSource = prevSource
	return section, nil
}

func (p *HyprlandParser) handleSource(line string, section *HyprlandSection, baseDir string) {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return
	}

	sourcePath := strings.TrimSpace(parts[1])
	isHYPESource := sourcePath == "hype/binds.conf" || strings.HasSuffix(sourcePath, "/hype/binds.conf") || sourcePath == "hype/binds.conf" || strings.HasSuffix(sourcePath, "/hype/binds.conf")

	p.includeCount++
	if isHYPESource {
		p.hypeBindsIncluded = true
		p.hypeIncludePos = p.includeCount
		p.hypeProcessed = true
	}

	fullPath := sourcePath
	if !filepath.IsAbs(sourcePath) {
		fullPath = filepath.Join(baseDir, sourcePath)
	}

	expanded, err := utils.ExpandPath(fullPath)
	if err != nil {
		return
	}

	includedSection, err := p.parseFileWithSource(expanded, "")
	if err != nil {
		return
	}

	section.Children = append(section.Children, *includedSection)
}

func (p *HyprlandParser) parseHYPEBindsDirectly(hypeBindsPath string, section *HyprlandSection) {
	data, err := os.ReadFile(hypeBindsPath)
	if err != nil {
		return
	}

	prevSource := p.currentSource
	p.currentSource = hypeBindsPath

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "bind") {
			continue
		}

		kb := p.parseBindLine(line)
		if kb == nil {
			continue
		}
		kb.Source = hypeBindsPath
		if p.addBind(kb) {
			section.Keybinds = append(section.Keybinds, *kb)
		}
	}

	p.currentSource = prevSource
	p.hypeProcessed = true
}

func (p *HyprlandParser) parseBindLine(line string) *HyprlandKeyBinding {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return nil
	}

	// Extract bind type and flags from the left side of "="
	bindType := strings.TrimSpace(parts[0])
	flags := extractBindFlags(bindType)
	hasDescFlag := strings.Contains(flags, "d")

	keys := parts[1]
	keyParts := strings.SplitN(keys, "#", 2)
	keys = keyParts[0]

	var comment string
	if len(keyParts) > 1 {
		comment = strings.TrimSpace(keyParts[1])
	}

	// For bindd, the format is: bindd = MODS, key, description, dispatcher, params
	// For regular binds: bind = MODS, key, dispatcher, params
	var minFields, descIndex, dispatcherIndex int
	if hasDescFlag {
		minFields = 4 // mods, key, description, dispatcher
		descIndex = 2
		dispatcherIndex = 3
	} else {
		minFields = 3 // mods, key, dispatcher
		dispatcherIndex = 2
	}

	keyFields := strings.SplitN(keys, ",", minFields+2) // Allow for params
	if len(keyFields) < minFields {
		return nil
	}

	mods := strings.TrimSpace(keyFields[0])
	key := strings.TrimSpace(keyFields[1])

	var dispatcher, params string
	if hasDescFlag {
		// bindd format: description is in the bind itself
		if comment == "" {
			comment = strings.TrimSpace(keyFields[descIndex])
		}
		dispatcher = strings.TrimSpace(keyFields[dispatcherIndex])
		if len(keyFields) > dispatcherIndex+1 {
			paramParts := keyFields[dispatcherIndex+1:]
			params = strings.TrimSpace(strings.Join(paramParts, ","))
		}
	} else {
		dispatcher = strings.TrimSpace(keyFields[dispatcherIndex])
		if len(keyFields) > dispatcherIndex+1 {
			paramParts := keyFields[dispatcherIndex+1:]
			params = strings.TrimSpace(strings.Join(paramParts, ","))
		}
	}

	if comment != "" && strings.HasPrefix(comment, HideComment) {
		return nil
	}

	if comment == "" {
		comment = hyprlandAutogenerateComment(dispatcher, params)
	}

	var modList []string
	if mods != "" {
		modstring := mods + string(ModSeparators[0])
		idx := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range ModSeparators {
				if char == sep {
					isModSep = true
					break
				}
			}
			if isModSep {
				if index-idx > 1 {
					modList = append(modList, modstring[idx:index])
				}
				idx = index + 1
			}
		}
	}

	return &HyprlandKeyBinding{
		Mods:       modList,
		Key:        key,
		Dispatcher: dispatcher,
		Params:     params,
		Comment:    comment,
		Flags:      flags,
	}
}

// extractBindFlags extracts the flags from a bind type string
// e.g., "binde" -> "e", "bindel" -> "el", "bindd" -> "d"
func extractBindFlags(bindType string) string {
	bindType = strings.TrimSpace(bindType)
	if !strings.HasPrefix(bindType, "bind") {
		return ""
	}
	return bindType[4:] // Everything after "bind"
}

func ParseHyprlandKeysWithHYPE(path string) (*HyprlandParseResult, error) {
	parser := NewHyprlandParser(path)
	section, err := parser.ParseWithHYPE()
	if err != nil {
		return nil, err
	}

	return &HyprlandParseResult{
		Section:            section,
		HYPEBindsIncluded:   parser.hypeBindsIncluded,
		HYPEStatus:          parser.buildHYPEStatus(),
		ConflictingConfigs: parser.conflictingConfigs,
	}, nil
}
