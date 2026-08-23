/****************************************************************************
** Meta object code from reading C++ file 'settingsManager.hpp'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/core/settings/settingsManager.hpp"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'settingsManager.hpp' doesn't include <QObject>."
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
struct qt_meta_tag_ZN4xyla15SettingsManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto xyla::SettingsManager::qt_create_metaobjectdata<qt_meta_tag_ZN4xyla15SettingsManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "xyla::SettingsManager",
        "settingsChanged",
        "",
        "xyla::XylaSettingsData",
        "data",
        "themeChanged",
        "uiScaleChanged",
        "autoSaveEnabledChanged",
        "autoSaveIntervalMinutesChanged",
        "maxRecentProjectsChanged",
        "reopenLastProjectOnStartupChanged",
        "theme",
        "uiScale",
        "autoSaveEnabled",
        "autoSaveIntervalMinutes",
        "maxRecentProjects",
        "reopenLastProjectOnStartup"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'settingsChanged'
        QtMocHelpers::SignalData<void(const xyla::XylaSettingsData &)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Signal 'themeChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'uiScaleChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'autoSaveEnabledChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'autoSaveIntervalMinutesChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'maxRecentProjectsChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'reopenLastProjectOnStartupChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'theme'
        QtMocHelpers::PropertyData<QString>(11, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'uiScale'
        QtMocHelpers::PropertyData<double>(12, QMetaType::Double, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'autoSaveEnabled'
        QtMocHelpers::PropertyData<bool>(13, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'autoSaveIntervalMinutes'
        QtMocHelpers::PropertyData<int>(14, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 4),
        // property 'maxRecentProjects'
        QtMocHelpers::PropertyData<int>(15, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 5),
        // property 'reopenLastProjectOnStartup'
        QtMocHelpers::PropertyData<bool>(16, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 6),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<SettingsManager, qt_meta_tag_ZN4xyla15SettingsManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject xyla::SettingsManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla15SettingsManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla15SettingsManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4xyla15SettingsManagerE_t>.metaTypes,
    nullptr
} };

void xyla::SettingsManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SettingsManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->settingsChanged((*reinterpret_cast<std::add_pointer_t<xyla::XylaSettingsData>>(_a[1]))); break;
        case 1: _t->themeChanged(); break;
        case 2: _t->uiScaleChanged(); break;
        case 3: _t->autoSaveEnabledChanged(); break;
        case 4: _t->autoSaveIntervalMinutesChanged(); break;
        case 5: _t->maxRecentProjectsChanged(); break;
        case 6: _t->reopenLastProjectOnStartupChanged(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)(const xyla::XylaSettingsData & )>(_a, &SettingsManager::settingsChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)()>(_a, &SettingsManager::themeChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)()>(_a, &SettingsManager::uiScaleChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)()>(_a, &SettingsManager::autoSaveEnabledChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)()>(_a, &SettingsManager::autoSaveIntervalMinutesChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)()>(_a, &SettingsManager::maxRecentProjectsChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (SettingsManager::*)()>(_a, &SettingsManager::reopenLastProjectOnStartupChanged, 6))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->theme(); break;
        case 1: *reinterpret_cast<double*>(_v) = _t->uiScale(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->autoSaveEnabled(); break;
        case 3: *reinterpret_cast<int*>(_v) = _t->autoSaveIntervalMinutes(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->maxRecentProjects(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->reopenLastProjectOnStartup(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setTheme(*reinterpret_cast<QString*>(_v)); break;
        case 1: _t->setUiScale(*reinterpret_cast<double*>(_v)); break;
        case 2: _t->setAutoSaveEnabled(*reinterpret_cast<bool*>(_v)); break;
        case 3: _t->setAutoSaveIntervalMinutes(*reinterpret_cast<int*>(_v)); break;
        case 4: _t->setMaxRecentProjects(*reinterpret_cast<int*>(_v)); break;
        case 5: _t->setReopenLastProjectOnStartup(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *xyla::SettingsManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *xyla::SettingsManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4xyla15SettingsManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int xyla::SettingsManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 7)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 7;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 7)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 7;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void xyla::SettingsManager::settingsChanged(const xyla::XylaSettingsData & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void xyla::SettingsManager::themeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void xyla::SettingsManager::uiScaleChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void xyla::SettingsManager::autoSaveEnabledChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void xyla::SettingsManager::autoSaveIntervalMinutesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void xyla::SettingsManager::maxRecentProjectsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void xyla::SettingsManager::reopenLastProjectOnStartupChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}
QT_WARNING_POP
