/****************************************************************************
**
** Copyright (C) 2019 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the demonstration applications of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** BSD License Usage
** Alternatively, you may use this file under the terms of the BSD license
** as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/
#define GL_SILENCE_DEPRECATION // annoying OpenGL warnings from Apple's headers

#include "metaltextureimport.h"
#include <QtGui/QScreen>
#include <QtQuick/QQuickWindow>
#include <QtQuick/QSGTextureProvider>
#include <QtQuick/QSGSimpleTextureNode>
#include <QtCore/QFile>

#include <MetalANGLE/MGLKit.h>
#include <MetalANGLE/EGL/egl.h>
#define EGL_EGLEXT_PROTOTYPES
#include <MetalANGLE/EGL/eglext.h>
#include <MetalANGLE/GLES2/gl2.h>
#include <MetalANGLE/GLES2/gl2ext.h>

#include <Metal/Metal.h>

extern "C"
{
// Third party maths library
#include "../maths/CC3GLMatrix.h"
}

namespace
{

struct Vertex
{
    float Position[3];
    float Color[4];
};

const Vertex kVertices[] = {
    // Front
    {{1, -1, 0}, {1, 0, 0, 1}},
    {{1, 1, 0}, {0, 1, 0, 1}},
    {{-1, 1, 0}, {0, 0, 1, 1}},
    {{-1, -1, 0}, {0, 0, 0, 1}},
    // Back
    {{1, 1, -2}, {1, 0, 0, 1}},
    {{-1, -1, -2}, {0, 1, 0, 1}},
    {{1, -1, -2}, {0, 0, 1, 1}},
    {{-1, 1, -2}, {0, 0, 0, 1}},
    // Left
    {{-1, -1, 0}, {1, 0, 0, 1}},
    {{-1, 1, 0}, {0, 1, 0, 1}},
    {{-1, 1, -2}, {0, 0, 1, 1}},
    {{-1, -1, -2}, {0, 0, 0, 1}},
    // Right
    {{1, -1, -2}, {1, 0, 0, 1}},
    {{1, 1, -2}, {0, 1, 0, 1}},
    {{1, 1, 0}, {0, 0, 1, 1}},
    {{1, -1, 0}, {0, 0, 0, 1}},
    // Top
    {{1, 1, 0}, {1, 0, 0, 1}},
    {{1, 1, -2}, {0, 1, 0, 1}},
    {{-1, 1, -2}, {0, 0, 1, 1}},
    {{-1, 1, 0}, {0, 0, 0, 1}},
    // Bottom
    {{1, -1, -2}, {1, 0, 0, 1}},
    {{1, -1, 0}, {0, 1, 0, 1}},
    {{-1, -1, 0}, {0, 0, 1, 1}},
    {{-1, -1, -2}, {0, 0, 0, 1}}};

const GLubyte kIndices[] = {
    // Front
    0, 1, 2, 2, 3, 0,
    // Back
    4, 5, 6, 6, 7, 4,
    // Left
    8, 9, 10, 10, 11, 8,
    // Right
    12, 13, 14, 14, 15, 12,
    // Top
    16, 17, 18, 18, 19, 16,
    // Bottom
    20, 21, 22, 22, 23, 20};
}

//! [1]
class CustomTextureNode : public QSGTextureProvider, public QSGSimpleTextureNode
{
    Q_OBJECT

public:
    CustomTextureNode(QQuickItem *item);
    ~CustomTextureNode();

    QSGTexture *texture() const override;

    void sync();
//! [1]
private slots:
    void render();
    void renderEnd();

private:
    enum Stage {
        VertexStage,
        FragmentStage
    };
    void cleanupGLTexture();
    void prepareGLFunctionPointers();
    void prepareGLTexture();
    void prepareSemaphore();
    void prepareShaders();
    GLuint prepareShader(GLenum stage);
    GLuint compileShaderFromSource(GLenum stage, const QByteArray &src);

    void doGLRender();

    QQuickItem *m_item;
    QQuickWindow *m_window;
    QSize m_size;
    qreal m_dpr;
    id<MTLDevice> m_device = nil;
    id<MTLTexture> m_texture = nil;
    id<MTLSharedEvent> m_semaphore = nil;

    uint64_t m_semaphoreCounter = 0;

    bool m_initialized = false;

    MGLContext *m_contextMGL = nil;
    GLuint m_fboGL = 0;
    GLuint m_textureGL = 0;
    GLuint m_depthBufferGL = 0;
    EGLImageKHR m_imageEGL = 0;
    GLuint m_semaphoreGL = 0;

    GLuint m_shaderProgramGL = 0;
    GLint m_positionSlot = -1;
    GLint m_colorSlot = -1;
    GLint m_projectionUniform = -1;
    GLint m_modelViewUniform = -1;

    float m_t;

    PFNGLEGLIMAGETARGETTEXTURE2DOESPROC glEGLImageTargetTexture2DOES = nullptr;

    PFNGLIMPORTSEMAPHOREFDEXTPROC glImportSemaphoreFdEXT = nullptr;

    PFNGLGENSEMAPHORESEXTPROC glGenSemaphoresEXT       = nullptr;
    PFNGLDELETESEMAPHORESEXTPROC glDeleteSemaphoresEXT = nullptr;
    PFNGLSEMAPHOREPARAMETERUI64VEXTPROC glSemaphoreParameterui64vEXT = nullptr;
    PFNGLWAITSEMAPHOREEXTPROC glWaitSemaphoreEXT       = nullptr;
    PFNGLSIGNALSEMAPHOREEXTPROC glSignalSemaphoreEXT   = nullptr;
};

CustomTextureItem::CustomTextureItem()
{
    setFlag(ItemHasContents, true);
}

// The beauty of using a true QSGNode: no need for complicated cleanup
// arrangements, unlike in other examples like metalunderqml, because the
// scenegraph will handle destroying the node at the appropriate time.

void CustomTextureItem::invalidateSceneGraph() // called on the render thread when the scenegraph is invalidated
{
    m_node = nullptr;
}

void CustomTextureItem::releaseResources() // called on the gui thread if the item is removed from scene
{
    m_node = nullptr;
}

//! [2]
QSGNode *CustomTextureItem::updatePaintNode(QSGNode *node, UpdatePaintNodeData *)
{
    CustomTextureNode *n = static_cast<CustomTextureNode *>(node);

    if (!n && (width() <= 0 || height() <= 0))
        return nullptr;

    if (!n) {
        m_node = new CustomTextureNode(this);
        n = m_node;
    }

    m_node->sync();

    n->setTextureCoordinatesTransform(QSGSimpleTextureNode::NoTransform);
    n->setFiltering(QSGTexture::Linear);
    n->setRect(0, 0, width(), height());

    window()->update(); // ensure getting to beforeRendering() at some point

    return n;
}
//! [2]

void CustomTextureItem::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);

    if (newGeometry.size() != oldGeometry.size())
        update();
}

void CustomTextureItem::setT(qreal t)
{
    if (t == m_t)
        return;

    m_t = t;
    emit tChanged();

    update();
}

//! [3]
CustomTextureNode::CustomTextureNode(QQuickItem *item)
    : m_item(item)
{
    m_window = m_item->window();
    connect(m_window, &QQuickWindow::beforeRendering, this, &CustomTextureNode::render);
    connect(m_window, &QQuickWindow::afterRendering, this, &CustomTextureNode::renderEnd);
    connect(m_window, &QQuickWindow::screenChanged, this, [this]() {
        if (m_window->effectiveDevicePixelRatio() != m_dpr)
            m_item->update();
    });
//! [3]

    qDebug("renderer created");
}

CustomTextureNode::~CustomTextureNode()
{
    cleanupGLTexture();

    if (m_semaphoreGL) {
        glDeleteSemaphoresEXT(1, &m_semaphoreGL);
        m_semaphoreGL = 0;
    }

    if (m_shaderProgramGL) {
        glDeleteProgram(m_shaderProgramGL);
        m_shaderProgramGL = 0;
    }

    [m_contextMGL release];

    delete texture();
    [m_texture release];
    [m_semaphore release];

    qDebug("renderer destroyed");
}

QSGTexture *CustomTextureNode::texture() const
{
    return QSGSimpleTextureNode::texture();
}

void CustomTextureNode::cleanupGLTexture()
{
    if (m_fboGL) {
        glDeleteFramebuffers(1, &m_fboGL);
        m_fboGL = 0;
    }
    if (m_textureGL) {
        glDeleteTextures(1, &m_textureGL);
        m_textureGL = 0;
    }
    if (m_imageEGL) {
        eglDestroyImageKHR(m_contextMGL.eglDisplay, m_imageEGL);
        m_imageEGL = 0;
    }

    if (m_depthBufferGL) {
        glDeleteRenderbuffers(1, &m_depthBufferGL);
        m_depthBufferGL = 0;
    }
}

//! [4]
void CustomTextureNode::sync()
{
    m_dpr = m_window->effectiveDevicePixelRatio();
    const QSize newSize = m_window->size() * m_dpr;
    bool needsNew = false;

    if (!texture())
        needsNew = true;

    if (newSize != m_size) {
        needsNew = true;
        m_size = newSize;
    }

    if (!m_contextMGL) {
        m_contextMGL = [[MGLContext alloc] initWithAPI:kMGLRenderingAPIOpenGLES2];
        [MGLContext setCurrentContext:m_contextMGL];
        prepareGLFunctionPointers();
    }

    if (needsNew) {
        delete texture();
        [m_texture release];

        QSGRendererInterface *rif = m_window->rendererInterface();
        m_device = (id<MTLDevice>) rif->getResource(m_window, QSGRendererInterface::DeviceResource);
        Q_ASSERT(m_device);

        // Create Metal texture
        MTLTextureDescriptor *desc = [[MTLTextureDescriptor alloc] init];
        desc.textureType = MTLTextureType2D;
        desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
        desc.width = m_size.width();
        desc.height = m_size.height();
        desc.mipmapLevelCount = 1;
        desc.resourceOptions = MTLResourceStorageModePrivate;
        desc.storageMode = MTLStorageModePrivate;
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        m_texture = [m_device newTextureWithDescriptor: desc];
        [desc release];

        // Bind Metal texture to OpenGL's texture object
        prepareGLTexture();

        // Qt texture wrapper
        QSGTexture *wrapper = QNativeInterface::QSGMetalTexture::fromNative(m_texture, m_window, m_size);

        qDebug() << "Got QSGTexture wrapper" << wrapper << "for an MTLTexture of size" << m_size;

        setTexture(wrapper);
    }
//! [4]
    if (!m_initialized && texture()) {
        m_initialized = true;

        prepareSemaphore();
        prepareShaders();

        qDebug("resources initialized");
    }

//! [5]
    m_t = float(static_cast<CustomTextureItem *>(m_item)->t());
//! [5]
}

// This is hooked up to beforeRendering() so we can start our own render
// command encoder. If we instead wanted to use the scenegraph's render command
// encoder (targeting the window), it should be connected to
// beforeRenderPassRecording() instead.
//! [6]
void CustomTextureNode::render()
{
    if (!m_initialized)
        return;

    // Render to m_texture using OpenGL
    [MGLContext setCurrentContext:m_contextMGL];

    // Wait for Metal side to finish using the texture (this waiting will happen on GPU side, not here,
    // it won't block here). We have to use semaphore because MetalANGLE and Qt use different
    // Metal command queue.
    glSemaphoreParameterui64vEXT(m_semaphoreGL, GL_TIMELINE_SEMAPHORE_VALUE_MGL, &m_semaphoreCounter);
    const GLenum imageLayout = GL_LAYOUT_COLOR_ATTACHMENT_EXT;
    glWaitSemaphoreEXT(m_semaphoreGL, 0, nullptr, 1, &m_textureGL, &imageLayout);

    // Do OpenGL draws
    doGLRender();

    // Notify Metal side that the rendering has happened
    m_semaphoreCounter++;
    glSemaphoreParameterui64vEXT(m_semaphoreGL, GL_TIMELINE_SEMAPHORE_VALUE_MGL, &m_semaphoreCounter);
    glSignalSemaphoreEXT(m_semaphoreGL, 0, nullptr, 1, &m_textureGL, &imageLayout);

    QSGRendererInterface *rif = m_window->rendererInterface();
    id<MTLCommandBuffer> cb = (id<MTLCommandBuffer>) rif->getResource(m_window, QSGRendererInterface::CommandListResource);
    Q_ASSERT(cb);
    [cb encodeWaitForEvent:m_semaphore value:m_semaphoreCounter];
}
//! [6]

void CustomTextureNode::doGLRender()
{
    glBindFramebuffer(GL_FRAMEBUFFER, m_fboGL);

    // Setup uniforms
    glUseProgram(m_shaderProgramGL);

    CC3GLMatrix *projection = [CC3GLMatrix matrix];
    float h                 = 4.0f * m_texture.height / m_texture.width;
    [projection populateFromFrustumLeft:-2
                               andRight:2
                              andBottom:-h / 2
                                 andTop:h / 2
                                andNear:4
                                 andFar:10];
    glUniformMatrix4fv(m_projectionUniform, 1, 0, projection.glMatrix);

    CC3GLMatrix *modelView = [CC3GLMatrix matrix];
    [modelView populateFromTranslation:CC3VectorMake(sin(std::fmod(CACurrentMediaTime(), 2 * M_PI)), 0, -7)];
    float currentRotation = std::fmod(CACurrentMediaTime() * 90, 360);
    [modelView rotateBy:CC3VectorMake(currentRotation, currentRotation, 0)];
    glUniformMatrix4fv(m_modelViewUniform, 1, 0, modelView.glMatrix);

    glViewport(0, 0, m_texture.width, m_texture.height);

    glClearColor(0, 104.0 / 255.0, 55.0 / 255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glEnableVertexAttribArray(m_positionSlot);
    glEnableVertexAttribArray(m_colorSlot);
    glVertexAttribPointer(m_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), kVertices);
    glVertexAttribPointer(m_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), &kVertices[0].Color);

    glDrawElements(GL_TRIANGLES, sizeof(kIndices) / sizeof(kIndices[0]), GL_UNSIGNED_BYTE, kIndices);
}

void CustomTextureNode::renderEnd()
{
    // Notify OpenGL side that Metal has issued the rendering commands using the shared texture
    QSGRendererInterface *rif = m_window->rendererInterface();
    id<MTLCommandBuffer> cb = (id<MTLCommandBuffer>) rif->getResource(m_window, QSGRendererInterface::CommandListResource);
    Q_ASSERT(cb);

    m_semaphoreCounter++;
    [cb encodeSignalEvent:m_semaphore value:m_semaphoreCounter];
}

void CustomTextureNode::prepareGLFunctionPointers()
{
    // Use function pointers to avoid conflict with Apple's GL header
#define GET_GL_PROC(name) name = reinterpret_cast<__typeof__(name)>(eglGetProcAddress(#name))

    GET_GL_PROC(glEGLImageTargetTexture2DOES);

    GET_GL_PROC(glImportSemaphoreFdEXT);

    GET_GL_PROC(glGenSemaphoresEXT);
    GET_GL_PROC(glDeleteSemaphoresEXT);
    GET_GL_PROC(glWaitSemaphoreEXT);
    GET_GL_PROC(glSignalSemaphoreEXT);
    GET_GL_PROC(glSemaphoreParameterui64vEXT);
}

void CustomTextureNode::prepareGLTexture()
{
    // Required extensions (if using MetalANGLE and the running macOS version is 10.14+, these extensions are guaranteed to exist)
    const auto eglExtensions = reinterpret_cast<const char *>(eglQueryString(m_contextMGL.eglDisplay, EGL_EXTENSIONS));
    Q_ASSERT(strstr(eglExtensions, "EGL_MGL_mtl_texture_client_buffer"));

    // Check that MetalANGLE uses the same Metal device as Qt
    EGLAttrib angleDevice = 0;
    EGLAttrib device      = 0;
    eglQueryDisplayAttribEXT(m_contextMGL.eglDisplay, EGL_DEVICE_EXT, &angleDevice);

    eglQueryDeviceAttribEXT(reinterpret_cast<EGLDeviceEXT>(angleDevice),
                                            EGL_MTL_DEVICE_ANGLE, &device);

    Q_ASSERT((__bridge id<MTLDevice>)reinterpret_cast<void *>(device) == m_device);

    cleanupGLTexture();

    // Bind metal texture to OpenGL's texture object
    constexpr EGLint kDefaultEGLImageAttribs[] = {
        EGL_NONE,
    };
    m_imageEGL =
        eglCreateImageKHR(m_contextMGL.eglDisplay, EGL_NO_CONTEXT, EGL_MTL_TEXTURE_MGL,
                          reinterpret_cast<EGLClientBuffer>(m_texture), kDefaultEGLImageAttribs);

    // Create a texture target to bind the egl image
    glGenTextures(1, &m_textureGL);
    glBindTexture(GL_TEXTURE_2D, m_textureGL);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, m_imageEGL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // Create depth buffer
    glGenRenderbuffers(1, &m_depthBufferGL);
    glBindRenderbuffer(GL_RENDERBUFFER, m_depthBufferGL);
    glRenderbufferStorage(GL_RENDERBUFFER,
                          GL_DEPTH_COMPONENT16,
                          (GLsizei)m_texture.width,
                          (GLsizei)m_texture.height);

    // Create framebuffer object
    glGenFramebuffers(1, &m_fboGL);
    glBindFramebuffer(GL_FRAMEBUFFER, m_fboGL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_textureGL, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, m_depthBufferGL);
    Q_ASSERT(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
}

void CustomTextureNode::prepareSemaphore()
{
    // First, create Metal shared event
    m_semaphore = [m_device newSharedEvent];
    m_semaphore.signaledValue = m_semaphoreCounter;

    // Required extensions (if using MetalANGLE and the running macOS version is 10.14+, these extensions are guaranteed to exist)
    const auto glExtensions = reinterpret_cast<const char *>(glGetString(GL_EXTENSIONS));
    Q_ASSERT(strstr(glExtensions, "GL_EXT_semaphore"));
    Q_ASSERT(strstr(glExtensions, "GL_EXT_semaphore_fd"));
    Q_ASSERT(strstr(glExtensions, "GL_MGL_timeline_semaphore"));

    // Write to file and pass its fd to OpenGL.
    // NOTE: fd will be owned by OpenGL, so don't close it.
    char name[] = "/tmp/XXXXXX";
    int tmpFd;
    tmpFd = mkstemp(name);
    unlink(name);

    void *sharedEventPtr = (__bridge void *)m_semaphore;
    pwrite(tmpFd, &sharedEventPtr, sizeof(sharedEventPtr), 0);

    // Import shared event to OpenGL as semaphore object
    glGenSemaphoresEXT(1, &m_semaphoreGL);
    glImportSemaphoreFdEXT(m_semaphoreGL, GL_HANDLE_TYPE_OPAQUE_FD_EXT, tmpFd);
}

void CustomTextureNode::prepareShaders()
{
    GLuint vertexShader = prepareShader(GL_VERTEX_SHADER);
    GLuint fragmentShader = prepareShader(GL_FRAGMENT_SHADER);

    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    glLinkProgram(programHandle);

    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }

    glUseProgram(programHandle);
    m_shaderProgramGL = programHandle;

    m_positionSlot = glGetAttribLocation(programHandle, "Position");
    m_colorSlot    = glGetAttribLocation(programHandle, "SourceColor");

    m_projectionUniform = glGetUniformLocation(programHandle, "Projection");
    m_modelViewUniform  = glGetUniformLocation(programHandle, "Modelview");
}

GLuint CustomTextureNode::prepareShader(GLenum stage)
{
    QString filename;
    if (stage == GL_VERTEX_SHADER) {
        filename = QLatin1String(":/scenegraph/metaltextureimport/squircle.vert");
    } else {
        Q_ASSERT(stage == GL_FRAGMENT_SHADER);
        filename = QLatin1String(":/scenegraph/metaltextureimport/squircle.frag");
    }
    QFile f(filename);
    if (!f.open(QIODevice::ReadOnly))
        qFatal("Failed to read shader %s", qPrintable(filename));

    const QByteArray contents = f.readAll();

    return compileShaderFromSource(stage, contents);
}

GLuint CustomTextureNode::compileShaderFromSource(GLenum stage, const QByteArray &src)
{
    GLuint shaderHandle = glCreateShader(stage);

    const char *shaderStringUTF8 = src.constData();
    int shaderStringLength       = (int)src.length();
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);

    glCompileShader(shaderHandle);

    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }

    return shaderHandle;
}

#include "metaltextureimport.moc"
