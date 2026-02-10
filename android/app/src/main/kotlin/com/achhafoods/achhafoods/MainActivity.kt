package com.achhafoods.achhafoods

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // We call enableEdgeToEdge() if the context allows it
        // but for most Flutter apps, the default FlutterActivity
        // handles the layout perfectly fine.
        super.onCreate(savedInstanceState)
    }
}

//package com.achhafoods.achhafoods
//
//import android.os.Bundle
//import io.flutter.embedding.android.FlutterActivity
//
//class MainActivity: FlutterActivity(){}