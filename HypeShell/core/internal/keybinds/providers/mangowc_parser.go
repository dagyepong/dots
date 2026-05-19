package providers

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/acarlton5/HypeShell/core/internal/utils"
)

const (
	MangoWCHideComment = "[hidden]"
)

var MangoWCModSeparators = []rune{'+', ' '}

type MangoWCKeyBinding struct {
	Mods    []string `json:"mods"`
	Key     string   `json:"key"`
	Command string   `json:"command"`
	Params  string   `json:"params"`
	Comment string   `json:"comment"`
	Source  string   `json:"source"`
}

type MangoWCParser struct {
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
	conflictingConfigs map[string]*MangoWCKeyBinding
	bindMap            map[string]*MangoWCKeyBinding
	bindOrder          []string
	processedFiles     map[string]bool
	hypeProcessed       bool
}

func NewMangoWCParser(configDir string) *MangoWCParser {
	return &MangoWCParser{
		contentLines:       []string{},
		readingLine:        0,
		configDir:          configDir,
		hypeIncludePos:      -1,
		hypeBindKeys:        make(map[string]bool),
		configBindKeys:     make(map[string]bool),
		conflictingConfigs: make(map[string]*MangoWCKeyBinding),
		bindMap:            make(map[string]*MangoWCKeyBinding),
		bindOrder:          []string{},
		processedFiles:     make(map[string]bool),
	}
}

func (p *MangoWCParser) ReadContent(path string) error {
	expandedPath, err := utils.ExpandPath(path)
	if err != nil {
		return err
	}

	info, err := os.Stat(expandedPath)
	if err != nil {
		return err
	}

	var files []string
	if info.IsDir() {
		confFiles, err := filepath.Glob(filepath.Join(expandedPath, "*.conf"))
		if err != nil {
			return err
		}
		if len(confFiles) == 0 {
			return os.ErrNotExist
		}
		files = confFiles
	} else {
		files = []string{expandedPath}
	}

	var combinedContent []string
	for _, file := range files {
		if fileInfo, err := os.Stat(file); err == nil && fileInfo.Mode().IsRegular() {
			data, err := os.ReadFile(file)
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

func mangowcAutogenerateComment(command, params string) string {
	switch command {
	case "spawn", "spawn_shell":
		return params
	case "killclient":
		return "Close window"
	case "quit":
		return "Exit MangoWC"
	case "reload_config":
		return "Reload configuration"
	case "focusstack":
		if params == "next" {
			return "Focus next window"
		}
		if params == "prev" {
			return "Focus previous window"
		}
		return "Focus stack " + params
	case "focusdir":
		dirMap := map[string]string{
			"left":  "left",
			"right": "right",
			"up":    "up",
			"down":  "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "Focus " + dir
		}
		return "Focus " + params
	case "exchange_client":
		dirMap := map[string]string{
			"left":  "left",
			"right": "right",
			"up":    "up",
			"down":  "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "Swap window " + dir
		}
		return "Swap window " + params
	case "togglefloating":
		return "Float/unfloat window"
	case "togglefullscreen":
		return "Toggle fullscreen"
	case "togglefakefullscreen":
		return "Toggle fake fullscreen"
	case "togglemaximizescreen":
		return "Toggle maximize"
	case "toggleglobal":
		return "Toggle global"
	case "toggleoverview":
		return "Toggle overview"
	case "toggleoverlay":
		return "Toggle overlay"
	case "minimized":
		return "Minimize window"
	case "restore_minimized":
		return "Restore minimized"
	case "toggle_scratchpad":
		return "Toggle scratchpad"
	case "setlayout":
		return "Set layout " + params
	case "switch_layout":
		return "Switch layout"
	case "view":
		parts := strings.Split(params, ",")
		if len(parts) > 0 {
			return "View tag " + parts[0]
		}
		return "View tag"
	case "tag":
		parts := strings.Split(params, ",")
		if len(parts) > 0 {
			return "Move to tag " + parts[0]
		}
		return "Move to tag"
	case "toggleview":
		parts := strings.Split(params, ",")
		if len(parts) > 0 {
			return "Toggle tag " + parts[0]
		}
		return "Toggle tag"
	case "viewtoleft", "viewtoleft_have_client":
		return "View left tag"
	case "viewtoright", "viewtoright_have_client":
		return "View right tag"
	case "tagtoleft":
		return "Move to left tag"
	case "tagtoright":
		return "Move to right tag"
	case "focusmon":
		return "Focus monitor " + params
	case "tagmon":
		return "Move to monitor " + params
	case "incgaps":
		if strings.HasPrefix(params, "-") {
			return "Decrease gaps"
		}
		return "Increase gaps"
	case "togglegaps":
		return "Toggle gaps"
	case "movewin":
		return "Move window by " + params
	case "resizewin":
		return "Resize window by " + params
	case "set_proportion":
		return "Set proportion " + params
	case "switch_proportion_preset":
		return "Switch proportion preset"
	default:
		return ""
	}
}

func (p *MangoWCParser) getKeybindAtLine(lineNumber int) *MangoWCKeyBinding {
	if lineNumber >= len(p.contentLines) {
		return nil
	}

	line := p.contentLines[lineNumber]

	bindMatch := regexp.MustCompile(`^(bind[lsr]*)\s*=\s*(.+)$`)
	matches := bindMatch.FindStringSubmatch(line)
	if len(matches) < 3 {
		return nil
	}

	bindType := matches[1]
	content := matches[2]

	parts := strings.SplitN(content, "#", 2)
	keys := parts[0]

	var comment string
	if len(parts) > 1 {
		comment = strings.TrimSpace(parts[1])
	}

	if strings.HasPrefix(comment, MangoWCHideComment) {
		return nil
	}

	keyFields := strings.SplitN(keys, ",", 4)
	if len(keyFields) < 3 {
		return nil
	}

	mods := strings.TrimSpace(keyFields[0])
	key := strings.TrimSpace(keyFields[1])
	command := strings.TrimSpace(keyFields[2])

	var params string
	if len(keyFields) > 3 {
		params = strings.TrimSpace(keyFields[3])
	}

	if comment == "" {
		comment = mangowcAutogenerateComment(command, params)
	}

	var modList []string
	if mods != "" && !strings.EqualFold(mods, "none") {
		modstring := mods + string(MangoWCModSeparators[0])
		p := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range MangoWCModSeparators {
				if char == sep {
					isModSep = true
					break
				}
			}
			if isModSep {
				if index-p > 1 {
					modList = append(modList, modstring[p:index])
				}
				p = index + 1
			}
		}
	}

	_ = bindType

	return &MangoWCKeyBinding{
		Mods:    modList,
		Key:     key,
		Command: command,
		Params:  params,
		Comment: comment,
	}
}

func (p *MangoWCParser) ParseKeys() []MangoWCKeyBinding {
	var keybinds []MangoWCKeyBinding

	for lineNumber := 0; lineNumber < len(p.contentLines); lineNumber++ {
		line := p.contentLines[lineNumber]
		if line == "" || strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}

		if !strings.HasPrefix(strings.TrimSpace(line), "bind") {
			continue
		}

		keybind := p.getKeybindAtLine(lineNumber)
		if keybind != nil {
			keybinds = append(keybinds, *keybind)
		}
	}

	return keybinds
}

func ParseMangoWCKeys(path string) ([]MangoWCKeyBinding, error) {
	parser := NewMangoWCParser(path)
	if err := parser.ReadContent(path); err != nil {
		return nil, err
	}
	return parser.ParseKeys(), nil
}

type MangoWCParseResult struct {
	Keybinds           []MangoWCKeyBinding
	HYPEBindsIncluded   bool
	HYPEStatus          *MangoWCHYPEStatus
	ConflictingConfigs map[string]*MangoWCKeyBinding
}

type MangoWCHYPEStatus struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	BindsAfterHYPE   int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
}

func (p *MangoWCParser) buildHYPEStatus() *MangoWCHYPEStatus {
	status := &MangoWCHYPEStatus{
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
		status.StatusMessage = "Some HYPE binds may be overridden by config binds"
	default:
		status.Effective = true
		status.StatusMessage = "HYPE binds are active"
	}

	return status
}

func (p *MangoWCParser) formatBindKey(kb *MangoWCKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (p *MangoWCParser) normalizeKey(key string) string {
	return strings.ToLower(key)
}

func (p *MangoWCParser) addBind(kb *MangoWCKeyBinding) {
	key := p.formatBindKey(kb)
	normalizedKey := p.normalizeKey(key)
	isHYPEBind := strings.Contains(kb.Source, "hype/binds.conf") || strings.Contains(kb.Source, "hype"+string(os.PathSeparator)+"binds.conf")

	if isHYPEBind {
		p.hypeBindKeys[normalizedKey] = true
	} else if p.hypeBindKeys[normalizedKey] {
		p.bindsAfterHYPE++
		p.conflictingConfigs[normalizedKey] = kb
		p.configBindKeys[normalizedKey] = true
		return
	} else {
		p.configBindKeys[normalizedKey] = true
	}

	if _, exists := p.bindMap[normalizedKey]; !exists {
		p.bindOrder = append(p.bindOrder, key)
	}
	p.bindMap[normalizedKey] = kb
}

func (p *MangoWCParser) ParseWithHYPE() ([]MangoWCKeyBinding, error) {
	expandedDir, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}

	hypeBindsPath := filepath.Join(expandedDir, "hype", "binds.conf")
	if _, err := os.Stat(hypeBindsPath); err == nil {
		p.hypeBindsExists = true
	}

	mainConfig := filepath.Join(expandedDir, "config.conf")
	if _, err := os.Stat(mainConfig); os.IsNotExist(err) {
		mainConfig = filepath.Join(expandedDir, "mango.conf")
	}

	_, err = p.parseFileWithSource(mainConfig)
	if err != nil {
		return nil, err
	}

	if p.hypeBindsExists && !p.hypeProcessed {
		p.parseHYPEBindsDirectly(hypeBindsPath)
	}

	var keybinds []MangoWCKeyBinding
	for _, key := range p.bindOrder {
		normalizedKey := p.normalizeKey(key)
		if kb, exists := p.bindMap[normalizedKey]; exists {
			keybinds = append(keybinds, *kb)
		}
	}

	return keybinds, nil
}

func (p *MangoWCParser) parseFileWithSource(filePath string) ([]MangoWCKeyBinding, error) {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, err
	}

	if p.processedFiles[absPath] {
		return nil, nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, err
	}

	prevSource := p.currentSource
	p.currentSource = absPath

	var keybinds []MangoWCKeyBinding
	lines := strings.Split(string(data), "\n")

	for lineNum, line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "source") {
			p.handleSource(trimmed, filepath.Dir(absPath), &keybinds)
			continue
		}

		if !strings.HasPrefix(trimmed, "bind") {
			continue
		}

		kb := p.getKeybindAtLineContent(line, lineNum)
		if kb == nil {
			continue
		}
		kb.Source = p.currentSource
		p.addBind(kb)
		keybinds = append(keybinds, *kb)
	}

	p.currentSource = prevSource
	return keybinds, nil
}

func (p *MangoWCParser) handleSource(line, baseDir string, keybinds *[]MangoWCKeyBinding) {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return
	}

	sourcePath := strings.TrimSpace(parts[1])
	isHYPESource := sourcePath == "hype/binds.conf" || sourcePath == "./hype/binds.conf" || strings.HasSuffix(sourcePath, "/hype/binds.conf")

	p.includeCount++
	if isHYPESource {
		p.hypeBindsIncluded = true
		p.hypeIncludePos = p.includeCount
		p.hypeProcessed = true
	}

	expanded, err := utils.ExpandPath(sourcePath)
	if err != nil {
		return
	}

	fullPath := expanded
	if !filepath.IsAbs(expanded) {
		fullPath = filepath.Join(baseDir, expanded)
	}

	includedBinds, err := p.parseFileWithSource(fullPath)
	if err != nil {
		return
	}

	*keybinds = append(*keybinds, includedBinds...)
}

func (p *MangoWCParser) parseHYPEBindsDirectly(hypeBindsPath string) []MangoWCKeyBinding {
	keybinds, err := p.parseFileWithSource(hypeBindsPath)
	if err != nil {
		return nil
	}
	p.hypeProcessed = true
	return keybinds
}

func (p *MangoWCParser) getKeybindAtLineContent(line string, _ int) *MangoWCKeyBinding {
	bindMatch := regexp.MustCompile(`^(bind[lsr]*)\s*=\s*(.+)$`)
	matches := bindMatch.FindStringSubmatch(line)
	if len(matches) < 3 {
		return nil
	}

	content := matches[2]
	parts := strings.SplitN(content, "#", 2)
	keys := parts[0]

	var comment string
	if len(parts) > 1 {
		comment = strings.TrimSpace(parts[1])
	}

	if strings.HasPrefix(comment, MangoWCHideComment) {
		return nil
	}

	keyFields := strings.SplitN(keys, ",", 4)
	if len(keyFields) < 3 {
		return nil
	}

	mods := strings.TrimSpace(keyFields[0])
	key := strings.TrimSpace(keyFields[1])
	command := strings.TrimSpace(keyFields[2])

	var params string
	if len(keyFields) > 3 {
		params = strings.TrimSpace(keyFields[3])
	}

	if comment == "" {
		comment = mangowcAutogenerateComment(command, params)
	}

	var modList []string
	if mods != "" && !strings.EqualFold(mods, "none") {
		modstring := mods + string(MangoWCModSeparators[0])
		idx := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range MangoWCModSeparators {
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

	return &MangoWCKeyBinding{
		Mods:    modList,
		Key:     key,
		Command: command,
		Params:  params,
		Comment: comment,
	}
}

func ParseMangoWCKeysWithHYPE(path string) (*MangoWCParseResult, error) {
	parser := NewMangoWCParser(path)
	keybinds, err := parser.ParseWithHYPE()
	if err != nil {
		return nil, err
	}

	return &MangoWCParseResult{
		Keybinds:           keybinds,
		HYPEBindsIncluded:   parser.hypeBindsIncluded,
		HYPEStatus:          parser.buildHYPEStatus(),
		ConflictingConfigs: parser.conflictingConfigs,
	}, nil
}
