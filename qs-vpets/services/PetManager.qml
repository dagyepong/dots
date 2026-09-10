pragma Singleton

import Quickshell

Singleton {
    property var pets: []
    function register(pet: var): void { pets = pets.concat([pet]); }
    function unregister(pet: var): void { pets = pets.filter(p => p !== pet); }
}
