import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'SWS',
  description: 'Swift Window Shell — native macOS hotkey utility belt',
  // Deployed at https://merv1n34k.github.io/sws/ — paths need this prefix.
  base: '/sws/',
  cleanUrls: true,
  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/installation' },
      { text: 'Modes', link: '/modes/terminal' },
      { text: 'GitHub', link: 'https://github.com/merv1n34k/sws' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Getting started',
          items: [
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Configuration', link: '/guide/configuration' },
            { text: 'Hotkeys', link: '/guide/hotkeys' },
          ],
        },
        {
          text: 'Under the hood',
          items: [
            { text: 'Architecture', link: '/guide/architecture' },
            { text: 'Adding a mode', link: '/guide/adding-modes' },
          ],
        },
      ],
      '/modes/': [
        {
          text: 'Modes',
          items: [
            { text: 'Terminal', link: '/modes/terminal' },
            { text: 'Color', link: '/modes/color' },
            { text: 'Time', link: '/modes/time' },
            { text: 'Status', link: '/modes/status' },
            { text: 'EnDe', link: '/modes/ende' },
            { text: 'Generators', link: '/modes/generators' },
            { text: 'Clipboard', link: '/modes/clipboard' },
            { text: 'OCR', link: '/modes/ocr' },
            { text: 'Scratchpad', link: '/modes/scratchpad' },
          ],
        },
      ],
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/merv1n34k/sws' },
    ],
    search: { provider: 'local' },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Native macOS — Swift + AppKit.',
    },
  },
})
