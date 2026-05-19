package params

import "fmt"

func Get[T any](params map[string]any, key string) (T, error) {
	val, ok := params[key].(T)
	if !ok {
		var zero T
		return zero, fmt.Errorf("missing or invalid '%s' parameter", key)
	}
	return val, nil
}

func GetOpt[T any](params map[string]any, key string, def T) T {
	if val, ok := params[key].(T); ok {
		return val
	}
	return def
}

func String(params map[string]any, key string) (string, error) {
	return Get[string](params, key)
}

func StringNonEmpty(params map[string]any, key string) (string, error) {
	val, err := Get[string](params, key)
	if err != nil || val == "" {
		return "", fmt.Errorf("missing or invalid '%s' parameter", key)
	}
	return val, nil
}

func StringOpt(params map[string]any, key string, def string) string {
	return GetOpt(params, key, def)
}

func Int(params map[string]any, key string) (int, error) {
	val, err := Get[float64](params, key)
	if err != nil {
		return 0, err
	}
	return int(val), nil
}

func IntOpt(params map[string]any, key string, def int) int {
	if val, ok := params[key].(float64); ok {
		return int(val)
	}
	return def
}

func Float(params map[string]any, key string) (float64, error) {
	return Get[float64](params, key)
}

func FloatOpt(params map[string]any, key string, def float64) float64 {
	return GetOpt(params, key, def)
}

func Bool(params map[string]any, key string) (bool, error) {
	return Get[bool](params, key)
}

func BoolOpt(params map[string]any, key string, def bool) bool {
	return GetOpt(params, key, def)
}

func StringMap(params map[string]any, key string) (map[string]string, error) {
	rawMap, err := Get[map[string]any](params, key)
	if err != nil {
		return nil, err
	}
	result := make(map[string]string)
	for k, v := range rawMap {
		if str, ok := v.(string); ok {
			result[k] = str
		}
	}
	return result, nil
}

func StringMapOpt(params map[string]any, key string) map[string]string {
	rawMap, ok := params[key].(map[string]any)
	if !ok {
		return nil
	}
	result := make(map[string]string)
	for k, v := range rawMap {
		if str, ok := v.(string); ok {
			result[k] = str
		}
	}
	return result
}

func Any(params map[string]any, key string) (any, bool) {
	val, ok := params[key]
	return val, ok
}

func AnyMap(params map[string]any, key string) (map[string]any, bool) {
	val, ok := params[key].(map[string]any)
	return val, ok
}

func StringAlt(params map[string]any, keys ...string) (string, bool) {
	for _, key := range keys {
		if val, ok := params[key].(string); ok {
			return val, true
		}
	}
	return "", false
}
