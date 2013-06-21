package main

import (
	"errors"
	"log"

	"github.com/go-gl/gl"
)

const (
	POSITION = 0
)

var (
	CUBE_VERTICES [3*4*6]float32 = [3*4*6]float32{
		0., 0., 0.,	//front
		0., 1., 0.,
		1., 1., 0.,
		1., 0., 0.,

		0., 0., 0.,	//bottom
		1., 0., 0.,
		1., 0., 1.,
		0., 0., 1.,

		0., 0., 0.,	//left side
		0., 0., 1.,
		0., 1., 1.,
		0., 1., 0.,

		1., 1., 1.,	//back
		0., 1., 1.,
		0., 0., 1.,
		1., 0., 1.,

		1., 1., 1.,	//top
		1., 1., 0.,
		0., 1., 0.,
		0., 1., 1.,

		1., 1., 1.,	//right side
		1., 0., 1.,
		1., 0., 0.,
		1., 1., 0.,
	}
	CUBE_COLORS [3*4*6]float32 = [3*4*6]float32{
		1., 0., 0.,	//red
		1., 0., 0.,
		1., 0., 0.,
		1., 0., 0.,

		1., 1., 0.,	//yellow
		1., 1., 0.,
		1., 1., 0.,
		1., 1., 0.,

		0., 0., 1.,	//blue
		0., 0., 1.,
		0., 0., 1.,
		0., 0., 1.,

		1., 0., 0.,	//red
		1., 0., 0.,
		1., 0., 0.,
		1., 0., 0.,

		1., 1., 0.,	//yellow
		1., 1., 0.,
		1., 1., 0.,
		1., 1., 0.,

		0., 0., 1.,	//blue
		0., 0., 1.,
		0., 0., 1.,
		0., 0., 1.,
	}
	CUBE_INDICES [4*6]uint = [4*6]uint{
		0, 1, 2, 3,
		4, 5, 6, 7,
		8, 9, 10, 11,
		12,13,14,15,
		16,17,18,19,
		20,21,22,23,
	}
)

// Model represents a renderable 3D object stored in OpenGL.
type Model struct {
	numIndices int
	vao []gl.VertexArray
	buffers []gl.Buffer
}

func ToError(enum gl.GLenum) (err error) {
	switch {
	case enum == gl.NO_ERROR:
		err = nil
	case enum == gl.INVALID_ENUM:
		err = errors.New("GLenum: INVALID_ENUM")
	case enum == gl.INVALID_VALUE:
		err = errors.New("GLenum: INVALID_VALUE")
	case enum == gl.INVALID_OPERATION:
		err = errors.New("GLenum: INVALID_OPERATION")
	case enum == gl.STACK_OVERFLOW:
		err = errors.New("GLenum: STACK_OVERFLOW")
	case enum == gl.STACK_UNDERFLOW:
		err = errors.New("GLenum: STACK_UNDERFLOW")
	case enum == gl.OUT_OF_MEMORY:
		err = errors.New("GLenum: OUT_OF_MEMORY")
	case enum == gl.TABLE_TOO_LARGE:
		err = errors.New("GLenum: TABLE_TOO_LARGE")
	default:
		err = errors.New("GLenum: undefined")
	}
	return
}

// NewModel creates a simple cube model.
func NewModel(program gl.Program) (m Model) {
	
	m.vao = new([1]gl.VertexArray)[:]
	
	gl.GenVertexArrays(m.vao)
	m.vao[POSITION].Bind()
	vertLoc := program.GetAttribLocation("a_position")
	
	m.buffers = make([]gl.Buffer, 2, 2)
	gl.GenBuffers(m.buffers)
	
	
	// Vertex buffer
	m.buffers[0].Bind(gl.ARRAY_BUFFER)
	gl.BufferData(gl.ARRAY_BUFFER, 3*4*6*4, &CUBE_VERTICES, gl.STATIC_DRAW);
	vertLoc.EnableArray();
	vertLoc.AttribPointer(3, gl.FLOAT, false, 0, nil);
	//vertLoc.DisableArray();
	
	// Index buffer
	m.numIndices = len(CUBE_INDICES)
	m.buffers[1].Bind(gl.ELEMENT_ARRAY_BUFFER)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, 4*m.numIndices, &CUBE_INDICES, gl.STATIC_DRAW)
	
	m.buffers[0].Unbind(gl.ARRAY_BUFFER)
	m.buffers[1].Unbind(gl.ELEMENT_ARRAY_BUFFER)

	if err := ToError(gl.GetError()); err != nil {
		log.Fatal(err)
	}

	return
}

// Render draws the model using OpenGL.
func (m Model) Render() {
	m.vao[POSITION].Bind()
	m.buffers[1].Bind(gl.ELEMENT_ARRAY_BUFFER)
	gl.DrawElements(gl.TRIANGLES, m.numIndices, gl.UNSIGNED_INT, nil)
	
	if err := ToError(gl.GetError()); err != nil {
		log.Fatal(err)
	}
}
