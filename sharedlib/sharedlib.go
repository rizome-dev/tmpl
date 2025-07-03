package main

// #include <stdlib.h>
import "C"
import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"runtime"
	"unsafe"
)

//export GetVersion
func GetVersion() *C.char {
	return C.CString("1.0.0")
}

//export GetPlatform
func GetPlatform() *C.char {
	return C.CString(fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH))
}

//export Sign
func Sign(data *C.char) *C.char {
	if data == nil {
		return C.CString("")
	}
	
	goData := C.GoString(data)
	hash := sha256.Sum256([]byte(goData))
	signature := hex.EncodeToString(hash[:])
	
	return C.CString(signature)
}

//export Verify
func Verify(data *C.char, signature *C.char) C.int {
	if data == nil || signature == nil {
		return 0
	}
	
	goData := C.GoString(data)
	goSignature := C.GoString(signature)
	
	hash := sha256.Sum256([]byte(goData))
	expectedSignature := hex.EncodeToString(hash[:])
	
	if expectedSignature == goSignature {
		return 1
	}
	return 0
}

//export FreeString
func FreeString(str *C.char) {
	C.free(unsafe.Pointer(str))
}

func main() {
	// Required for building shared library
}