package main

import (
	"fmt"
	"io/ioutil"

	"github.com/go-gl/gl"
	"github.com/go-gl/glfw"
)

func main() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.OpenWindowHint(glfw.OpenGLVersionMajor, 3)
	glfw.OpenWindowHint(glfw.OpenGLVersionMinor, 1)
	//glfw.OpenWindowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile)
	glfw.OpenWindow(800, 600, 0, 0, 0, 0, 16, 0, glfw.Windowed)
	defer glfw.CloseWindow()

	gl.Init()
	gl.ClearColor(0.2, 0.2, 0.2, 0.0)
	
	// Create shaders
	vs := gl.CreateShader(gl.VERTEX_SHADER)
	vs_source, _ := ioutil.ReadFile("basic.vs")
	vs.Source(string(vs_source))
	vs.Compile()
	fmt.Println(vs.GetInfoLog())
	
	fs := gl.CreateShader(gl.FRAGMENT_SHADER)
	fs_source, _ := ioutil.ReadFile("basic.fs")
	fs.Source(string(fs_source))
	fs.Compile()
	fmt.Println(fs.GetInfoLog())
	
	// Create shader program
	program := gl.CreateProgram()
	program.AttachShader(vs)
	program.AttachShader(fs)
	program.Validate()
	program.Link()
	program.Use()
	fmt.Println(program.GetInfoLog())
	
	// Setup uniforms
	
	var projMat Matrix4
	projMat.LoadOrthographic(-2, 2, -2, 2, -5, 5)
	a := projMat.Array()
	projLoc := program.GetUniformLocation("projection_matrix")
	projLoc.UniformMatrix4f(false, &a)
	sqt := NewSQT()
	mvLoc := program.GetUniformLocation("modelview_matrix")
	mat := sqt.Matrix()
	mvLoc.UniformMatrix4f(false, &mat)
	err()
	
	// Load model
	model := NewModel(program)

	for glfw.WindowParam(glfw.Opened) > 0 {
		// Input
		if glfw.Key(glfw.KeyEsc) == glfw.KeyPress {
			glfw.CloseWindow()
		}

		// Rendering
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
		model.Render()
		glfw.SwapBuffers()
	}
}
