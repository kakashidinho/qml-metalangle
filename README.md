# qml-metalangle
Example of mixing MetalANGLE with Qt's QML.

- This example is based on Qt's [metaltextureimport](https://code.qt.io/cgit/qt/qtdeclarative.git/tree/examples/quick/scenegraph/metaltextureimport?h=5.15) example.
- This example uses a shared Metal texture between MetalANGLE & Qt's Metal.
  - Unlike Qt's original example, this shared texture is drawn by MetalANGLE's GL commands.
- To ensure correct order of rendering (on MetalANGLE side) and consuming (on Qt's Metal side),
a shared semaphore also needs to be used. See [GL_EXT_semaphore](https://www.khronos.org/registry/OpenGL/extensions/EXT/EXT_external_objects.txt).

<img src="https://i.imgur.com/YEy7HvA.png" alt="drawing" width="400"/>

## In-depth explanation
- TODO
