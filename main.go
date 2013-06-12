package main

import (
	"github.com/go-gl/gl"
	"github.com/go-gl/glfw"
)

func main() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.OpenWindowHint(glfw.OpenGLVersionMajor, 3)
	glfw.OpenWindowHint(glfw.OpenGLVersionMinor, 1)
	glfw.OpenWindowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile)
	glfw.OpenWindow(800, 600, 0, 0, 0, 0, 16, 0, glfw.Windowed)
	defer glfw.CloseWindow()

	gl.Init()
	gl.ClearColor(0.5, 0.5, 0.5, 0.0)

	for glfw.WindowParam(glfw.Opened) > 0 {
		// Input
		if glfw.Key(glfw.KeyEsc) == glfw.KeyPress {
			glfw.CloseWindow()
		}

		// Rendering
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
		glfw.SwapBuffers()
	}
}
