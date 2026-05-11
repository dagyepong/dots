.pragma library

var TRANSFORM_LABELS = {
    0: "Normal",
    1: "90°",
    2: "180°",
    3: "270°",
    4: "Flipped",
    5: "Flipped 90°",
    6: "Flipped 180°",
    7: "Flipped 270°"
};

var ROTATE_OPTIONS = [
    { value: 0, label: "Normal" },
    { value: 1, label: "90°" },
    { value: 2, label: "180°" },
    { value: 3, label: "270°" },
    { value: 4, label: "Flipped" },
    { value: 5, label: "Flipped 90°" },
    { value: 6, label: "Flipped 180°" },
    { value: 7, label: "Flipped 270°" }
];

var SCALE_OPTIONS = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

function getTransformLabel(transform) {
    return TRANSFORM_LABELS[transform] || "Unknown";
}
