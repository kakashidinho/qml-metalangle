# qml-metalangle
Example of mixing MetalANGLE with Qt's QML.

- This example is based on Qt's [metaltextureimport](https://code.qt.io/cgit/qt/qtdeclarative.git/tree/examples/quick/scenegraph/metaltextureimport?h=5.15) example.
- This example uses a shared Metal texture between MetalANGLE & Qt's Metal.
  - Unlike Qt's original example, this shared texture is drawn by MetalANGLE's GL commands.
- To ensure correct order of rendering (on MetalANGLE side) and consuming (on Qt's Metal side),
a shared semaphore also needs to be used. See [GL_EXT_semaphore](https://www.khronos.org/registry/OpenGL/extensions/EXT/EXT_external_objects.txt).

<img src="https://i.imgur.com/YEy7HvA.png" alt="drawing" width="400"/>

## In-depth explanation
- Create an `MTLTexture`.
- Create an `MTLSharedEvent`.
- Import `MTLTexture` to OpenGL as a `GLuint` texture object. Attach it to an `FBO`.
- Import `MTLSharedEvent` to OpenGL as `GLuint` semaphore object.
- Initialize an integer `semaphoreCounter` to zero.
- Rendering loop:
  ```
  // Wait for Qt's Metal side to finish using the texture
  glSemaphoreParameterui64vEXT(..., GL_TIMELINE_SEMAPHORE_VALUE_MGL, &semaphoreCounter);
  glWaitSemaphoreEXT(...);

  // Draw to texture
  glBindFramebuffer(...);
  glClear(...)
  ...

  // Notify Qt's Metal side that the texture is safe to be used now
  semaphoreCounter++;
  glSemaphoreParameterui64vEXT(..., GL_TIMELINE_SEMAPHORE_VALUE_MGL, &semaphoreCounter);
  glSignalSemaphoreEXT(...);

  // On Qt's Metal side, wait for the semaphore's signal
  QSGRendererInterface *rif = m_window->rendererInterface();
  id<MTLCommandBuffer> cb = (id<MTLCommandBuffer>) rif->getResource(m_window, QSGRendererInterface::CommandListResource);
  [cb encodeWaitForEvent:... value:semaphoreCounter];

  // Display the texture on the screen (mostly done internally by QML scene graph)
  ...

  // Notify MetalANGLE side that the texture is safe to be rendered into now
  semaphoreCounter++;
  [cb encodeSignalEvent:... value:semaphoreCounter];
  ```
