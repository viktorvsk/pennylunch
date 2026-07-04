module IconsHelper
  DEFAULT_ICON_SIZE = "size-4"

  def icon_svg(name, class_name: DEFAULT_ICON_SIZE)
    paths = {
      basket: [
        tag.path(d: "M2 11h20"),
        tag.path(d: "m5 11 4-7"),
        tag.path(d: "m15 4 4 7"),
        tag.path(d: "m3.5 11 1.6 7.4A2 2 0 0 0 7 20h10a2 2 0 0 0 1.9-1.6l1.6-7.4"),
        tag.path(d: "M4.5 15.5h15"),
        tag.path(d: "m9 11 1 9"),
        tag.path(d: "m15 11-1 9")
      ],
      camera: [
        tag.path(d: "M14.5 4 16 6h3a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3l1.5-2h5Z"),
        tag.circle(cx: "12", cy: "13", r: "3")
      ],
      category: [
        tag.path(d: "M4 4h6v6H4z"),
        tag.path(d: "M14 4h6v6h-6z"),
        tag.path(d: "M4 14h6v6H4z"),
        tag.path(d: "M14 14h6v6h-6z")
      ],
      check: [
        tag.path(d: "M20 6 9 17l-5-5")
      ],
      clock: [
        tag.circle(cx: "12", cy: "12", r: "10"),
        tag.path(d: "M12 6v6l4 2")
      ],
      ingredients: [
        tag.path(d: "M2 11h20"),
        tag.path(d: "m5 11 4-7"),
        tag.path(d: "m15 4 4 7"),
        tag.path(d: "m3.5 11 1.6 7.4A2 2 0 0 0 7 20h10a2 2 0 0 0 1.9-1.6l1.6-7.4"),
        tag.path(d: "M4.5 15.5h15"),
        tag.path(d: "m9 11 1 9"),
        tag.path(d: "m15 11-1 9")
      ],
      popular: [
        tag.path(d: "M12 3.5 14.7 9l6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1L3.2 9l6.1-.9L12 3.5Z")
      ],
      quick: [
        tag.path(d: "M13 2 4 14h7l-1 8 9-12h-7l1-8Z")
      ],
      settings: [
        tag.circle(cx: "12", cy: "12", r: "3"),
        tag.path(d: "M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3 1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1h.1a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.3 1Z")
      ],
      sad_face: [
        tag.circle(cx: "12", cy: "12", r: "10"),
        tag.path(d: "M8 9h.01"),
        tag.path(d: "M16 9h.01"),
        tag.path(d: "M8 16a5 5 0 0 1 8 0")
      ],
      sort: [
        tag.path(d: "M7 6h10"),
        tag.path(d: "M7 12h7"),
        tag.path(d: "M7 18h4"),
        tag.path(d: "m17 15 3 3 3-3"),
        tag.path(d: "M20 6v12")
      ],
      sparkles: [
        tag.path(d: "M12 3 13.7 8.3 19 10l-5.3 1.7L12 17l-1.7-5.3L5 10l5.3-1.7L12 3Z"),
        tag.path(d: "M5 3v4"),
        tag.path(d: "M3 5h4"),
        tag.path(d: "M19 17v4"),
        tag.path(d: "M17 19h4")
      ],
      user: [
        tag.path(d: "M20 21a8 8 0 0 0-16 0"),
        tag.circle(cx: "12", cy: "7", r: "4")
      ]
    }

    tag.svg(
      safe_join(paths.fetch(name)),
      class: class_name,
      aria: { hidden: true },
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      stroke_width: "2",
      stroke_linecap: "round",
      stroke_linejoin: "round",
    )
  end
end
