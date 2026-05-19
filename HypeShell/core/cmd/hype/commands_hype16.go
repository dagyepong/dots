package main

import (
	"fmt"
	"strings"

	"github.com/acarlton5/HypeShell/core/internal/hype16"
	"github.com/acarlton5/HypeShell/core/internal/log"
	"github.com/spf13/cobra"
)

var hype16Cmd = &cobra.Command{
	Use:   "hype16 [hex_color]",
	Short: "Generate Base16 color palettes",
	Long:  "Generate Base16 color palettes from a color with support for various output formats",
	Args:  cobra.MaximumNArgs(1),
	Run:   runHype16,
}

func init() {
	hype16Cmd.Flags().Bool("light", false, "Generate light theme variant (sets default to light)")
	hype16Cmd.Flags().Bool("json", false, "Output in JSON format")
	hype16Cmd.Flags().Bool("kitty", false, "Output in Kitty terminal format")
	hype16Cmd.Flags().Bool("foot", false, "Output in Foot terminal format")
	hype16Cmd.Flags().Bool("neovim", false, "Output in Neovim plugin format")
	hype16Cmd.Flags().Bool("alacritty", false, "Output in Alacritty terminal format")
	hype16Cmd.Flags().Bool("ghostty", false, "Output in Ghostty terminal format")
	hype16Cmd.Flags().Bool("wezterm", false, "Output in Wezterm terminal format")
	hype16Cmd.Flags().String("background", "", "Custom background color")
	hype16Cmd.Flags().String("contrast", "dps", "Contrast algorithm: dps (Delta Phi Star, default) or wcag")
	hype16Cmd.Flags().Bool("variants", false, "Output all variants (dark/light/default) in JSON")
	hype16Cmd.Flags().String("primary-dark", "", "Primary color for dark mode (use with --variants)")
	hype16Cmd.Flags().String("primary-light", "", "Primary color for light mode (use with --variants)")
	_ = hype16Cmd.RegisterFlagCompletionFunc("contrast", func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		return []string{"dps", "wcag"}, cobra.ShellCompDirectiveNoFileComp
	})
}

func runHype16(cmd *cobra.Command, args []string) {
	isLight, _ := cmd.Flags().GetBool("light")
	isJson, _ := cmd.Flags().GetBool("json")
	isKitty, _ := cmd.Flags().GetBool("kitty")
	isFoot, _ := cmd.Flags().GetBool("foot")
	isNeovim, _ := cmd.Flags().GetBool("neovim")
	isAlacritty, _ := cmd.Flags().GetBool("alacritty")
	isGhostty, _ := cmd.Flags().GetBool("ghostty")
	isWezterm, _ := cmd.Flags().GetBool("wezterm")
	background, _ := cmd.Flags().GetString("background")
	contrastAlgo, _ := cmd.Flags().GetString("contrast")
	useVariants, _ := cmd.Flags().GetBool("variants")
	primaryDark, _ := cmd.Flags().GetString("primary-dark")
	primaryLight, _ := cmd.Flags().GetString("primary-light")

	if background != "" && !strings.HasPrefix(background, "#") {
		background = "#" + background
	}
	if primaryDark != "" && !strings.HasPrefix(primaryDark, "#") {
		primaryDark = "#" + primaryDark
	}
	if primaryLight != "" && !strings.HasPrefix(primaryLight, "#") {
		primaryLight = "#" + primaryLight
	}

	contrastAlgo = strings.ToLower(contrastAlgo)
	if contrastAlgo != "dps" && contrastAlgo != "wcag" {
		log.Fatalf("Invalid contrast algorithm: %s (must be 'dps' or 'wcag')", contrastAlgo)
	}

	if useVariants {
		if primaryDark == "" || primaryLight == "" {
			if len(args) == 0 {
				log.Fatalf("--variants requires either a positional color argument or both --primary-dark and --primary-light")
			}
			primaryColor := args[0]
			if !strings.HasPrefix(primaryColor, "#") {
				primaryColor = "#" + primaryColor
			}
			primaryDark = primaryColor
			primaryLight = primaryColor
		}
		variantOpts := hype16.VariantOptions{
			PrimaryDark:  primaryDark,
			PrimaryLight: primaryLight,
			Background:   background,
			UseDPS:       contrastAlgo == "dps",
			IsLightMode:  isLight,
		}
		variantColors := hype16.GenerateVariantPalette(variantOpts)
		fmt.Print(hype16.GenerateVariantJSON(variantColors))
		return
	}

	if len(args) == 0 {
		log.Fatalf("A color argument is required (or use --variants with --primary-dark and --primary-light)")
	}
	primaryColor := args[0]
	if !strings.HasPrefix(primaryColor, "#") {
		primaryColor = "#" + primaryColor
	}

	opts := hype16.PaletteOptions{
		IsLight:    isLight,
		Background: background,
		UseDPS:     contrastAlgo == "dps",
	}

	colors := hype16.GeneratePalette(primaryColor, opts)

	if isJson {
		fmt.Print(hype16.GenerateJSON(colors))
	} else if isKitty {
		fmt.Print(hype16.GenerateKittyTheme(colors))
	} else if isFoot {
		fmt.Print(hype16.GenerateFootTheme(colors))
	} else if isAlacritty {
		fmt.Print(hype16.GenerateAlacrittyTheme(colors))
	} else if isGhostty {
		fmt.Print(hype16.GenerateGhosttyTheme(colors))
	} else if isWezterm {
		fmt.Print(hype16.GenerateWeztermTheme(colors))
	} else if isNeovim {
		fmt.Print(hype16.GenerateNeovimTheme(colors))
	} else {
		fmt.Print(hype16.GenerateGhosttyTheme(colors))
	}
}
