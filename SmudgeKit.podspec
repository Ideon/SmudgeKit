Pod::Spec.new do |s|

  s.name         = "SmudgeKit"
  s.version      = "0.1.1"
  s.summary      = "A drop in replacement for UIWindow to draw touch points for app previews and promotional videos."

  s.description  = <<-DESC
                   SmudgeKit provides a drop in replacement for UIWindow to draw visual
                   representations of all touch events to the screen. Ideal for creating
                   App Previews or other screencasts where it is crucial to show touch
                   gestures. Not intended for production use.

                   Originally built to preview The Converted, check the [The Converted
                   website](http://ideon.co/theconverted?utm_source=github&utm_medium=readme&utm_campaign=smudgeKit)
                   for an example.
                   DESC

  s.homepage     = "https://github.com/Ideon/SmudgeKit"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Hans Petter Eikemo" => "hp@ideon.co" }
  s.social_media_url   = "https://twitter.com/hpeikemo"

  s.platform     = :ios, "6.0"

  s.source       = {
    :git => "https://github.com/Ideon/SmudgeKit.git",
    :tag => s.version.to_s,
    #:commit => "590857e0c0b5dd501410112393908a1bba7ef3b2",
    #:branch => "master",
  }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any h, m, mm, c & cpp files. For header
  #  files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

  s.source_files  = "Source-ObjectiveC/**/*.{h,m}"
  #s.exclude_files = "Classes/Exclude"

  # s.public_header_files = "Classes/**/*.h"

  s.requires_arc = true

end
