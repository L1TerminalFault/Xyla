/****************************************************************************
** Meta object code from reading C++ file 'menuManager.hpp'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/ui/menu/menuManager.hpp"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'menuManager.hpp' doesn't include <QObject>."
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
struct qt_meta_tag_ZN4xyla11MenuManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto xyla::MenuManager::qt_create_metaobjectdata<qt_meta_tag_ZN4xyla11MenuManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "xyla::MenuManager",
        "menuTreeChanged",
        "",
        "requestNewProject",
        "requestOpenProject",
        "requestSaveProject",
        "requestUndo",
        "requestRedo",
        "requestPreferences",
        "triggerAction",
        "actionId",
        "menuTree",
        "QVariantList"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'menuTreeChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'requestNewProject'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'requestOpenProject'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'requestSaveProject'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'requestUndo'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'requestRedo'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'requestPreferences'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'triggerAction'
        QtMocHelpers::MethodData<void(const QString &)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 10 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'menuTree'
        QtMocHelpers::PropertyData<QVariantList>(11, 0x80000000 | 12, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<MenuManager, qt_meta_tag_ZN4xyla11MenuManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject xyla::MenuManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla11MenuManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla11MenuManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4xyla11MenuManagerE_t>.metaTypes,
    nullptr
} };

void xyla::MenuManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<MenuManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->menuTreeChanged(); break;
        case 1: _t->requestNewProject(); break;
        case 2: _t->requestOpenProject(); break;
        case 3: _t->requestSaveProject(); break;
        case 4: _t->requestUndo(); break;
        case 5: _t->requestRedo(); break;
        case 6: _t->requestPreferences(); break;
        case 7: _t->triggerAction((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::menuTreeChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::requestNewProject, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::requestOpenProject, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::requestSaveProject, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::requestUndo, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::requestRedo, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (MenuManager::*)()>(_a, &MenuManager::requestPreferences, 6))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QVariantList*>(_v) = _t->menuTree(); break;
        default: break;
        }
    }
}

const QMetaObject *xyla::MenuManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *xyla::MenuManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla11MenuManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int xyla::MenuManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 8)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 8)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 8;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    }
    return _id;
}

// SIGNAL 0
void xyla::MenuManager::menuTreeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void xyla::MenuManager::requestNewProject()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void xyla::MenuManager::requestOpenProject()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void xyla::MenuManager::requestSaveProject()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void xyla::MenuManager::requestUndo()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void xyla::MenuManager::requestRedo()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void xyla::MenuManager::requestPreferences()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}
QT_WARNING_POP
