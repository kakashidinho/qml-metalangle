!macos:!ios: error("This example requires macOS or iOS")

QT += qml quick
CONFIG += qmltypes
QML_IMPORT_NAME = MetalTextureImport
QML_IMPORT_MAJOR_VERSION = 1

HEADERS += metaltextureimport.h
SOURCES += metaltextureimport.mm main.cpp
HEADERS += ../maths/CC3Foundation.h \
           ../maths/CC3Kazmath.h \
           ../maths/CC3Math.h \
           ../maths/CC3GLMatrix.h \
           ../maths/CC3Logging.h \
           ../maths/ccTypes.h
SOURCES += ../maths/CC3Foundation.m \
           ../maths/CC3GLMatrix.m \
           ../maths/CC3Math.m \
           ../maths/CC3Kazmath.c
RESOURCES += metaltextureimport.qrc

macos: QMAKE_CFLAGS += -F$$_PRO_FILE_PWD_/../frameworks/mac
macos: QMAKE_CXXFLAGS += -F$$_PRO_FILE_PWD_/../frameworks/mac
macos: LIBS += -F$$_PRO_FILE_PWD_/../frameworks/mac -framework AppKit
macos: QMAKE_RPATHDIR += $$_PRO_FILE_PWD_/../frameworks/mac
LIBS += -framework Metal -framework QuartzCore -framework MetalANGLE

target.path = $$[QT_INSTALL_EXAMPLES]/quick/scenegraph/metaltextureimport
INSTALLS += target
