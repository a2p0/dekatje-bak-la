class ThemeToggleComponent < ViewComponent::Base
  def call
    content_tag(:button,
      data: { action: "click->theme#toggle" },
      aria: { label: "Changer de thème" },
      class: "p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer") do
      # Sun icon (visible in dark mode)
      sun = content_tag(:svg, class: "w-5 h-5 hidden dark:block", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", stroke_width: "2") do
        content_tag(:path, "", stroke_linecap: "round", stroke_linejoin: "round",
          d: "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z")
      end
      # Moon icon (visible in light mode)
      moon = content_tag(:svg, class: "w-5 h-5 block dark:hidden", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", stroke_width: "2") do
        content_tag(:path, "", stroke_linecap: "round", stroke_linejoin: "round",
          d: "M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z")
      end
      sun + moon
    end
  end
end
