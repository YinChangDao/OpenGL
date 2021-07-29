//
//  GLView.swift
//  Traingle
//
//  Created by Ziyan Wu on 2021/7/23.
//

import UIKit
import OpenGLES

struct CustomVertex {
    var position: [Float]
    var color: [Float]
}

struct ShaderCompileError:Error {
    let compileLog:String
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
    var texture: GLuint = 0
    
    var glViewAttributes = [Int32]()
    
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
        setupVertexBuffer()
        let turple = decodeJPG()
        texture(rgbData: turple.0, width: turple.1, height: turple.2)
        attachShader()
    }
    
    func render() {
        glClearColor(0, 1, 1, 1)  // 设置画笔颜色
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))  // 清空viewport
        
        var backingWidth:GLint = 0
        var backingHeight:GLint = 0
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &backingWidth)
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &backingHeight)
        
        glViewport(0, 0, backingWidth, backingHeight)
        
        glBindTexture(GLenum(GL_TEXTURE_2D), texture);
        
        let position = glViewAttributes[0]
        let colors = glViewAttributes[1]
//        let inputByteSize = Int(self.frame.size.width * self.frame.size.height * 4)
//        let data = UnsafeMutablePointer<UInt8>.allocate(capacity:inputByteSize)
        
        glVertexAttribPointer(GLuint(position), GLint(4), GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*6), UnsafeRawPointer(bitPattern:0))
        
        glVertexAttribPointer(GLuint(colors), GLint(2), GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size*6), UnsafeRawPointer(bitPattern: MemoryLayout<GLfloat>.size*4))
                              
        glEnable(GLenum(GL_POINT_SIZE));
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        
        context.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    func setupFrameBuffer() {
        if frameBuffer != 0 {
            glDeleteFramebuffers(1, &frameBuffer)
            frameBuffer = 0
        }
        
        glGenFramebuffers(1, &frameBuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), renderBuffer) // 将渲染缓冲对象附加到帧缓冲的深度和模板附件上
    }
    
    func setupRenderBuffer() {
        glGenRenderbuffers(1, &renderBuffer) // 1 是个数，生成一个renderBuffer, 生成之后产生一个 ID 赋值给 renderBuffer
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderBuffer) // 绑定
        context.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer)
    }
    
    func setupVertexBuffer() {
        let vertexs:[GLfloat]  = [
            0.0, 1.0, 0.0, 1.0,    0.5, 0.0,
            -1.0, -1.0, 0.0, 1.0,  0.3, 1.0,
            1.0, -1.0, 0.0, 1.0,   0.7, 1.0
        ]
        
        var vertexBuffer: GLuint = 0
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GLfloat>.size * 18, vertexs, GLenum(GL_STATIC_DRAW))
        print("GLfloat size: ", MemoryLayout<GLfloat>.size)
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
    
    func compileShader(_ shaderName: String, for type: GLenum) -> GLuint {
        let shaderHandle: GLuint = glCreateShader(type)
        do {
            if let shaderPath = Bundle.main.path(forResource: shaderName, ofType: nil) {
                let shaderString = try String(contentsOfFile: shaderPath, encoding: .utf8)
                let shaderUTF8 = shaderString.cString(using: .utf8)!
                let shaderUTF8GLChar = UnsafePointer<GLchar>(shaderUTF8)
                var tempString:UnsafePointer<GLchar>? = shaderUTF8GLChar
                var shaderStringLength = GLint(shaderString.count)
                
                glShaderSource(shaderHandle, 1, &tempString, &shaderStringLength)
                glCompileShader(shaderHandle)
                
                var compileStatus:GLint = 1
                glGetShaderiv(shaderHandle, GLenum(GL_COMPILE_STATUS), &compileStatus)
                if (compileStatus != 1) {
                    var logLength:GLint = 0
                    glGetShaderiv(shaderHandle, GLenum(GL_INFO_LOG_LENGTH), &logLength)
                    if (logLength > 0) {
                        var compileLog = [CChar](repeating:0, count:Int(logLength))
                        
                        glGetShaderInfoLog(shaderHandle, logLength, &logLength, &compileLog)
                        print("Compile log: \(String(cString:compileLog))")
                        // let compileLogString = String(bytes:compileLog.map{UInt8($0)}, encoding:NSASCIIStringEncoding)
                    }
                }
                
                return shaderHandle
            }
        } catch let error {
            print("error: \(error)")
        }
        return shaderHandle
    }
    
    func attachShader() {
        let program = glCreateProgram()
        
        let vetexShader = compileShader("vertex.vsh", for: GLenum(GL_VERTEX_SHADER))
        let fragmentShader = compileShader("fragment.fsh", for: GLenum(GL_FRAGMENT_SHADER))
        
        glAttachShader(program, vetexShader)
        glAttachShader(program, fragmentShader)
        
        try! link(program: program)
        
        glUseProgram(program)
        print("attach ok")
    }
    
    func link(program: GLuint) throws {
        glLinkProgram(program)
        
        var linkStatus:GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &linkStatus)
        if (linkStatus == 0) {
            var logLength:GLint = 0
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            if (logLength > 0) {
                var compileLog = [CChar](repeating:0, count:Int(logLength))
                
                glGetProgramInfoLog(program, logLength, &logLength, &compileLog)
                print("Link log: \(String(cString:compileLog))")
            }
            
            throw ShaderCompileError(compileLog: "Link error")
        }
        
        glViewAttributes.append(glGetAttribLocation(program, "position"))
        glViewAttributes.append(glGetAttribLocation(program, "aTexCoord"))
        
        glEnableVertexAttribArray(GLuint(glViewAttributes[0]))
        glEnableVertexAttribArray(GLuint(glViewAttributes[1]))
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        render()
    }
    
    func texture(rgbData: UnsafeMutablePointer<UInt32>, width: Int, height: Int) {
        glGenTextures(1, &texture);
        glBindTexture(GLenum(GL_TEXTURE_2D), texture);
        // 为当前绑定的纹理对象设置环绕、过滤方式
        
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR);
        // 加载并生成纹理
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA), GLsizei(width), GLsizei(height), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), rgbData);
        
        free(rgbData)
    }
    
    func loadRGBFile() -> (UnsafeMutablePointer<UInt32>, Int, Int) {
        let filePath = Bundle.main.path(forResource: "1920x1200", ofType: "rgb24")
        
        do {
            var data = try Data(contentsOf: URL(fileURLWithPath: filePath!))
            let p: UnsafeMutablePointer<UInt32> = data.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer) -> UnsafeMutablePointer<UInt32> in
                pointer
            }
            
            return (p, 1920, 1200)
        } catch let error {
            print(error)
            return (UnsafeMutablePointer.allocate(capacity: 0), 0, 0)
        }
    }
    
    
    func decodeJPG() -> (UnsafeMutablePointer<UInt32>, Int, Int) {
        let inputCGImage = UIImage(named: "onepiece.jpg")!.cgImage!
        let alphaInfo = inputCGImage.alphaInfo
        let width = inputCGImage.width
        let height = inputCGImage.height

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let pixels = UnsafeMutablePointer<UInt32>.allocate(capacity: height * width * MemoryLayout<UInt32>.size)

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(data: pixels, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: alphaInfo.rawValue)

        context?.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        return (pixels, width, height)
    }
    

}
