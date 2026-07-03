// Package bdgcdl embeds the plugin-backed DoltLite build pack.
package bdgcdl

import "embed"

// PackFS contains the plugin-backed DoltLite build pack files.
//
//go:embed pack.toml agents commands skills template-fragments
var PackFS embed.FS
