package main

import (
	"math"
)

// Matrix4 represents a 4x4 matrix of floating-point values.
type Matrix4 [4][4]float32

// Array returns a one-dimensional array of the matrix.
func (m *Matrix4) Array() (a [16]float32) {
	for i := 0; i < 4; i++ {
		for j := 0; j < 4; j++ {
			a[i*4 + j] = m[i][j]
		}
	}
	return
}

// LoadIdentity replaces the current matrix with the identity matrix.
func (m *Matrix4) LoadIdentity() {
	for i := 0; i < 4; i++ {
		for j := 0; j < 4; j++ {
			if i == j {
				m[i][j] = 1
			} else {
				m[i][j] = 0
			}
		}
	}
}

// LoadOrthographic replaces the current matrix with an orthographic
// projection matrix.
func (m *Matrix4) LoadOrthographic(left, right, bottom, top, near, far float32) {
	rl := right - left
	tb := top - bottom
	fn := far - near
	
	m[0][0] = 2.0 / rl
	m[1][1] = 2.0 / tb
	m[2][2] = -2.0 / fn
	m[3][3] = 1.0
	
	m[0][3] = -(right+left)/rl
	m[1][3] = -(top+bottom)/tb
	m[2][3] = -(far+near)/fn
	
	m[0][1] = 0.0
	m[0][2] = 0.0
	m[1][0] = 0.0
	m[1][2] = 0.0
	m[2][0] = 0.0
	m[2][1] = 0.0
	m[3][0] = 0.0
	m[3][1] = 0.0
	m[3][2] = 0.0
}

// LoadPerspective replaces the current matrix with a perspective
// projection matrix.
func (m *Matrix4) LoadPerspective(fov, aspect, near, far float32) {
	f := 1.0 / float32(math.Tan(float64(fov/2.0)))
	d := near - far
	
	m[0][0] = f/aspect
	m[1][1] = f
	m[2][2] = (near+far)/d
	m[2][3] = (2.0*near*far)/d
	m[3][2] = -1.0
	
	m[0][1] = 0.0
	m[0][2] = 0.0
	m[0][3] = 0.0
	m[1][0] = 0.0
	m[1][2] = 0.0
	m[1][3] = 0.0
	m[2][0] = 0.0
	m[2][1] = 0.0
	m[3][0] = 0.0
	m[3][1] = 0.0
	m[3][3] = 0.0
}
