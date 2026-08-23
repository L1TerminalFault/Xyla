/****************************************************************************
** Meta object code from reading C++ file 'projectManager.hpp'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/project/projectManager.hpp"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'projectManager.hpp' doesn't include <QObject>."
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
struct qt_meta_tag_ZN4xyla14ProjectManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto xyla::ProjectManager::qt_create_metaobjectdata<qt_meta_tag_ZN4xyla14ProjectManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "xyla::ProjectManager",
        "activeProjectChanged",
        "",
        "projectOpenedSuccessfully",
        "unsavedChangesChanged",
        "createProject",
        "name",
        "directory",
        "width",
        "height",
        "fps",
        "videoTracks",
        "audioTracks",
        "openProject",
        "filePath",
        "saveProject",
        "closeProject",
        "hasActiveProject",
        "activeProjectName",
        "hasUnsavedChanges",
        "recentProjects",
        "RecentProjectsModel*"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'activeProjectChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'projectOpenedSuccessfully'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'unsavedChangesChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'createProject'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, int, int, int, int, int)>(5, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 6 }, { QMetaType::QString, 7 }, { QMetaType::Int, 8 }, { QMetaType::Int, 9 },
            { QMetaType::Int, 10 }, { QMetaType::Int, 11 }, { QMetaType::Int, 12 },
        }}),
        // Method 'createProject'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, int, int, int, int)>(5, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool, {{
            { QMetaType::QString, 6 }, { QMetaType::QString, 7 }, { QMetaType::Int, 8 }, { QMetaType::Int, 9 },
            { QMetaType::Int, 10 }, { QMetaType::Int, 11 },
        }}),
        // Method 'createProject'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, int, int, int)>(5, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool, {{
            { QMetaType::QString, 6 }, { QMetaType::QString, 7 }, { QMetaType::Int, 8 }, { QMetaType::Int, 9 },
            { QMetaType::Int, 10 },
        }}),
        // Method 'openProject'
        QtMocHelpers::MethodData<bool(const QString &)>(13, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 14 },
        }}),
        // Method 'saveProject'
        QtMocHelpers::MethodData<bool()>(15, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'closeProject'
        QtMocHelpers::MethodData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'hasActiveProject'
        QtMocHelpers::PropertyData<bool>(17, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'activeProjectName'
        QtMocHelpers::PropertyData<QString>(18, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'hasUnsavedChanges'
        QtMocHelpers::PropertyData<bool>(19, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'recentProjects'
        QtMocHelpers::PropertyData<RecentProjectsModel*>(20, 0x80000000 | 21, QMC::DefaultPropertyFlags | QMC::EnumOrFlag | QMC::Constant),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<ProjectManager, qt_meta_tag_ZN4xyla14ProjectManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject xyla::ProjectManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla14ProjectManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla14ProjectManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4xyla14ProjectManagerE_t>.metaTypes,
    nullptr
} };

void xyla::ProjectManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ProjectManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->activeProjectChanged(); break;
        case 1: _t->projectOpenedSuccessfully(); break;
        case 2: _t->unsavedChangesChanged(); break;
        case 3: { bool _r = _t->createProject((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[6])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[7])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 4: { bool _r = _t->createProject((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[6])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 5: { bool _r = _t->createProject((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[5])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 6: { bool _r = _t->openProject((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 7: { bool _r = _t->saveProject();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 8: _t->closeProject(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ProjectManager::*)()>(_a, &ProjectManager::activeProjectChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ProjectManager::*)()>(_a, &ProjectManager::projectOpenedSuccessfully, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (ProjectManager::*)()>(_a, &ProjectManager::unsavedChangesChanged, 2))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 3:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< RecentProjectsModel* >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->hasActiveProject(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->activeProjectName(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->hasUnsavedChanges(); break;
        case 3: *reinterpret_cast<RecentProjectsModel**>(_v) = _t->recentProjects(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 2: _t->setHasUnsavedChanges(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *xyla::ProjectManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *xyla::ProjectManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla14ProjectManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int xyla::ProjectManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 9)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 9;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 9)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 9;
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
void xyla::ProjectManager::activeProjectChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void xyla::ProjectManager::projectOpenedSuccessfully()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void xyla::ProjectManager::unsavedChangesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}
QT_WARNING_POP
