# Velarium
Name was straight up takes up from Claude with the prompt "Cool canvas names possibly from old times", 

Anyhow, this was made a **side project** after 3-modules into [Pikuma's 3-d Graphics Programming course](https://pikuma.com/courses/learn-3d-computer-graphics-programming), 

I'd just gained ability to render pixels onto screen and was bored with theory, which jump-started a month's journey into making a paint desktop application `(ik ik, initializes at 800x600, has single paint colors, so not really something a "cracked guy with high agency" would make)`

This how the pixel manipulation wizardry got me feelin' like though
![wizard with claude](https://github.com/user-attachments/assets/da3f91f1-059e-42ba-8bd8-2bd40cd4d66d)

Although the course was in C, i did this in Odin+SDL2 cover Odin exposure Side-Quest

Here is a small demo

![final_demo_opdin_app](https://github.com/user-attachments/assets/1d626141-b4be-404e-9630-f812705087c8)

# Usage

| Category | Command | Action |
|-----------|---------|---------|
| Basic Drawing | `D` + Mouse | Draw continuously |
| Shapes | `D + R` + Drag | Create rectangle |
| | `D + C` + Drag | Create circle |
| | `D + E` + Drag | Create ellipse |
| | `D + T` + Drag | Create triangle |
| | `D + L` + Drag | Create straight line |
| Area Operations | `F` | Fill enclosed area (red) |
| | `D + X` + Drag | Clear circular selection |
| Undo/Redo | `U` | Undo last action |
| | `R` | Redo last action |
| Controls | `ESC` | Exit application |
| | *Auto* | Display reference grid |

# Prerequisites
| Platform | Component | Installation |
|:---:|:---:|:---:|
| All | Odin Compiler | Install from [odin-lang.org/docs/install](https://odin-lang.org/docs/install/) <br> Add to system PATH |
| macOS | SDL2 | `brew install sdl2` |
| Linux | SDL2 | `sudo apt-get install libsdl2-dev` |
| Windows | SDL2 | 1. Download from [SDL Releases](https://github.com/libsdl-org/SDL/releases) <br> 2. Extract to `vendor/sdl2` in Odin directory |


# Building and Running
| Platform | Command |
|:---:|:---:|
| macOS | `odin run main.odin -file -extra-linker-flags:"-L/opt/homebrew/lib"` |
| Linux | `odin run main.odin -file` |
| Windows | `odin run main.odin -file` |


# Known Issues and Limitations

Window size is fixed at 800x600 pixels
Limited color palette (predefined colors only)
No file save/load functionality

# Contributing
Feel free to submit issues and enhancement requests. To contribute:
- Fork the repository
- Create a feature branch
- Commit your changes
- Push to the branch
- Create a Pull Request

# License
This project is open source and available under the MIT License.
