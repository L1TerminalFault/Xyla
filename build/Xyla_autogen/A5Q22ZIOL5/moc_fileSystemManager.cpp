/****************************************************************************
** Meta object code from reading C++ file 'fileSystemManager.hpp'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/project/fileSystemManager.hpp"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'fileSystemManager.hpp' doesn't include <QObject>."
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
struct qt_meta_tag_ZN4xyla15FileSystemModelE_t {};
} // unnamed namespace

template <> constexpr inline auto xyla::FileSystemModel::qt_create_metaobjectdata<qt_meta_tag_ZN4xyla15FileSystemModelE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "xyla::FileSystemModel",
        "currentPathChanged",
        "",
        "canCdBackChanged",
        "canCdForwardChanged",
        "cd",
        "path",
        "cdBack",
        "cdForward",
        "cdUp",
        "refresh",
        "makeFolder",
        "folderName",
        "currentPath",
        "parentPath",
        "canCdBack",
        "canCdForward"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'currentPathChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'canCdBackChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'canCdForwardChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'cd'
        QtMocHelpers::MethodData<void(const QString &)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 6 },
        }}),
        // Method 'cdBack'
        QtMocHelpers::MethodData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'cdForward'
        QtMocHelpers::MethodData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'cdUp'
        QtMocHelpers::MethodData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'refresh'
        QtMocHelpers::MethodData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'makeFolder'
        QtMocHelpers::MethodData<bool(const QString &)>(11, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 12 },
        }}),
        // Method 'makeFolder'
        QtMocHelpers::MethodData<bool()>(11, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'currentPath'
        QtMocHelpers::PropertyData<QString>(13, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'parentPath'
        QtMocHelpers::PropertyData<QString>(14, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'canCdBack'
        QtMocHelpers::PropertyData<bool>(15, QMetaType::Bool, QMC::DefaultPropertyFlags, 1),
        // property 'canCdForward'
        QtMocHelpers::PropertyData<bool>(16, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<FileSystemModel, qt_meta_tag_ZN4xyla15FileSystemModelE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject xyla::FileSystemModel::staticMetaObject = { {
    QMetaObject::SuperData::link<QAbstractListModel::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla15FileSystemModelE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla15FileSystemModelE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4xyla15FileSystemModelE_t>.metaTypes,
    nullptr
} };

void xyla::FileSystemModel::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<FileSystemModel *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->currentPathChanged(); break;
        case 1: _t->canCdBackChanged(); break;
        case 2: _t->canCdForwardChanged(); break;
        case 3: _t->cd((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 4: _t->cdBack(); break;
        case 5: _t->cdForward(); break;
        case 6: _t->cdUp(); break;
        case 7: _t->refresh(); break;
        case 8: { bool _r = _t->makeFolder((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 9: { bool _r = _t->makeFolder();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (FileSystemModel::*)()>(_a, &FileSystemModel::currentPathChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (FileSystemModel::*)()>(_a, &FileSystemModel::canCdBackChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (FileSystemModel::*)()>(_a, &FileSystemModel::canCdForwardChanged, 2))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->currentPath(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->parentPath(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->canCdBack(); break;
        case 3: *reinterpret_cast<bool*>(_v) = _t->canCdForward(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setCurrentPath(*reinterpret_cast<QString*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *xyla::FileSystemModel::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *xyla::FileSystemModel::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla15FileSystemModelE_t>.strings))
        return static_cast<void*>(this);
    return QAbstractListModel::qt_metacast(_clname);
}

int xyla::FileSystemModel::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QAbstractListModel::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 10)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 10;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 10)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 10;
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
void xyla::FileSystemModel::currentPathChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void xyla::FileSystemModel::canCdBackChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void xyla::FileSystemModel::canCdForwardChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}
QT_WARNING_POP
