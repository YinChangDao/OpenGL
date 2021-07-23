//
//  GLView.swift
//  Traingle
//
//  Created by Ziyan Wu on 2021/7/23.
//

import UIKit

struct CustomVertex {
    var position: [Float]
    var color: [Float]
}

class GLView: UIView {

    var eaglLayer: CAEAGLLayer {
        return self.layer as! CAEAGLLayer
    }
    lazy var context: EAGLContext = {
        let context = EAGLContext(api: .openGLES3)
        return context!
    }()
    var frameBuffer: GLuint = 0
    var renderBuffer: GLuint = 1
    
    override class var layerClass: AnyClass {
        return CAEAGLLayer.self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        EAGLContext.setCurrent(context)
        setupRenderBuffer()
        setupFrameBuffer()
    }
    
    func render() {
        glClearColor(0, 0, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        context.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    func setupFrameBuffer() {
        if frameBuffer != 0 {
            glDeleteFramebuffers(1, &frameBuffer)
            frameBuffer = 0
        }
        
        glGenFramebuffers(1, &frameBuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), renderBuffer)
    }
    
    func setupRenderBuffer() {
        glGenRenderbuffers(1, &renderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderBuffer)
        context.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer)
    }
    
    func setupVertexBuffer() {
        let vertices = [CustomVertex(position: [-1.0, 1.0, 0, 1], color: [1, 0, 0, 1]),
                        CustomVertex(position: [-1.0, -1.0, 0, 1], color: [0, 1, 0, 1]),
                        CustomVertex(position: [1.0, -1.0, 0, 1], color: [0, 0, 1, 1])]
        
        var vertexBuffer: GLuint = 0
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout.size(ofValue: vertices), vertices, GLenum(GL_STATIC_DRAW))
    }
    
    func checkFrameBuffer(_ error: NSErrorPointer) -> Bool {
        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        var msg: String? = nil
        var result = false
        
        switch status {
        case GLenum(GL_FRAMEBUFFER_UNSUPPORTED):
            msg = "framebuffer do not support the format"
        case GLenum(GL_FRAMEBUFFER_COMPLETE):
            result = true
        case GLenum(GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS):
            msg = "framebuffer incompleted image dimensions must be confirmed"
        case GLenum(GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT):
            msg = "framebuffer incompleted missing attachment"
        default:
            msg = "unknown error"
        }
        
        error?.pointee = (msg != nil) ? NSError(domain: "com.changdao.error", code: Int(status), userInfo: ["msg": msg ?? ""]) : nil
        
        return result
    }
    
//    func compileShader(_ shaderName: String, for type: GLenum) -> GLuint {
//        do {
//            if let shaderPath = Bundle.main.path(forResource: shaderName, ofType: nil) {
//                let shaderString = try String(contentsOfFile: shaderPath, encoding: .utf8)
//
//            }
//        } catch let error {
//            print("error: \(error)")
//        }
//    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        render()
    }
    

}
