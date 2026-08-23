/****************************************************************************
** Meta object code from reading C++ file 'xylaUndoStack.hpp'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/core/undo/xylaUndoStack.hpp"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'xylaUndoStack.hpp' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN4xyla13XylaUndoStackE_t {};
} // unnamed namespace

template <> constexpr inline auto xyla::XylaUndoStack::qt_create_metaobjectdata<qt_meta_tag_ZN4xyla13XylaUndoStackE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "xyla::XylaUndoStack",
        "canUndoChanged",
        "",
        "canUndo",
        "canRedoChanged",
        "canRedo",
        "indexChanged",
        "undo",
        "redo",
        "clear",
        "undoText",
        "redoText"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'canUndoChanged'
        QtMocHelpers::SignalData<void(bool)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 3 },
        }}),
        // Signal 'canRedoChanged'
        QtMocHelpers::SignalData<void(bool)>(4, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 5 },
        }}),
        // Signal 'indexChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'undo'
        QtMocHelpers::MethodData<bool()>(7, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'redo'
        QtMocHelpers::MethodData<bool()>(8, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'clear'
        QtMocHelpers::MethodData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'canUndo'
        QtMocHelpers::PropertyData<bool>(3, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'canRedo'
        QtMocHelpers::PropertyData<bool>(5, QMetaType::Bool, QMC::DefaultPropertyFlags, 1),
        // property 'undoText'
        QtMocHelpers::PropertyData<QString>(10, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'redoText'
        QtMocHelpers::PropertyData<QString>(11, QMetaType::QString, QMC::DefaultPropertyFlags, 1),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<XylaUndoStack, qt_meta_tag_ZN4xyla13XylaUndoStackE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject xyla::XylaUndoStack::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla13XylaUndoStackE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla13XylaUndoStackE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4xyla13XylaUndoStackE_t>.metaTypes,
    nullptr
} };

void xyla::XylaUndoStack::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<XylaUndoStack *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->canUndoChanged((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 1: _t->canRedoChanged((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 2: _t->indexChanged(); break;
        case 3: { bool _r = _t->undo();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 4: { bool _r = _t->redo();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 5: _t->clear(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (XylaUndoStack::*)(bool )>(_a, &XylaUndoStack::canUndoChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (XylaUndoStack::*)(bool )>(_a, &XylaUndoStack::canRedoChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (XylaUndoStack::*)()>(_a, &XylaUndoStack::indexChanged, 2))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->canUndo(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->canRedo(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->undoText(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->redoText(); break;
        default: break;
        }
    }
}

const QMetaObject *xyla::XylaUndoStack::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *xyla::XylaUndoStack::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla13XylaUndoStackE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int xyla::XylaUndoStack::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 6)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 6)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 6;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 4;
    }
    return _id;
}

// SIGNAL 0
void xyla::XylaUndoStack::canUndoChanged(bool _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void xyla::XylaUndoStack::canRedoChanged(bool _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}

// SIGNAL 2
void xyla::XylaUndoStack::indexChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}
QT_WARNING_POP
