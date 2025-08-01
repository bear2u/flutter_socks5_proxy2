package com.example.flutter_socks5_proxy

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import org.json.JSONArray
import org.json.JSONObject
import java.net.InetSocketAddress
import java.net.Proxy
import java.util.concurrent.TimeUnit

class FlutterSocks5ProxyPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val TAG = "FlutterSocks5Proxy"
        private const val CHANNEL_NAME = "flutter_socks5_proxy"
    }

    private lateinit var channel: MethodChannel
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    private var proxyClient: OkHttpClient? = null
    private var normalClient: OkHttpClient? = null
    private var currentConfig: ProxyConfig? = null
    private var isConnected = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        setupNormalClient()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getConnectionInfo" -> handleGetConnectionInfo(result)
            "testConnection" -> handleTestConnection(result)
            "request" -> handleRequest(call, result)
            "rpcRequest" -> handleRpcRequest(call, result)
            "getStatistics" -> handleGetStatistics(result)
            "resetStatistics" -> handleResetStatistics(result)
            else -> result.notImplemented()
        }
    }

    private fun setupNormalClient() {
        normalClient = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    private fun handleConnect(call: MethodCall, result: Result) {
        val host = call.argument<String>("host") ?: run {
            result.error("INVALID_ARGUMENT", "Host is required", null)
            return
        }
        
        val port = call.argument<Int>("port") ?: run {
            result.error("INVALID_ARGUMENT", "Port is required", null)
            return
        }
        
        val enableLogging = call.argument<Boolean>("enableLogging") ?: false
        val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 30
        
        scope.launch {
            try {
                Log.d(TAG, "Connecting to $host:$port")
                
                currentConfig = ProxyConfig(host, port)
                
                val loggingInterceptor = if (enableLogging) {
                    HttpLoggingInterceptor { message ->
                        Log.d(TAG, "[HTTP] $message")
                    }.apply {
                        level = HttpLoggingInterceptor.Level.BASIC
                    }
                } else null
                
                proxyClient = OkHttpClient.Builder()
                    .proxy(Proxy(Proxy.Type.SOCKS, InetSocketAddress(host, port)))
                    .connectTimeout(timeoutSeconds.toLong(), TimeUnit.SECONDS)
                    .readTimeout(timeoutSeconds.toLong(), TimeUnit.SECONDS)
                    .writeTimeout(timeoutSeconds.toLong(), TimeUnit.SECONDS)
                    .apply {
                        loggingInterceptor?.let { addInterceptor(it) }
                    }
                    .build()
                
                isConnected = true
                ProxyStatistics.reset()
                
                Log.d(TAG, "Connected to proxy: $host:$port")
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Connected to $host:$port"
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Connection failed", e)
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to false,
                        "error" to (e.message ?: "Connection failed")
                    ))
                }
            }
        }
    }

    private fun handleDisconnect(result: Result) {
        try {
            proxyClient = null
            currentConfig = null
            isConnected = false
            
            Log.d(TAG, "Disconnected from proxy")
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            result.success(mapOf(
                "success" to false,
                "error" to (e.message ?: "Disconnect failed")
            ))
        }
    }

    private fun handleGetConnectionInfo(result: Result) {
        result.success(mapOf(
            "isConnected" to isConnected,
            "host" to currentConfig?.host,
            "port" to currentConfig?.port
        ))
    }

    private fun handleTestConnection(result: Result) {
        if (!isConnected || proxyClient == null) {
            result.success(mapOf(
                "success" to false,
                "error" to "Not connected to proxy"
            ))
            return
        }
        
        scope.launch {
            try {
                val request = Request.Builder()
                    .url("https://ipinfo.io/json")
                    .build()
                
                ProxyStatistics.recordRequest("https://ipinfo.io/json")
                
                val response = proxyClient!!.newCall(request).execute()
                val body = response.body?.string() ?: ""
                
                if (response.isSuccessful) {
                    ProxyStatistics.recordSuccess(body.length.toLong())
                    
                    // Parse IP info
                    val jsonBody = JSONObject(body)
                    val ip = jsonBody.optString("ip")
                    val city = jsonBody.optString("city")
                    val country = jsonBody.optString("country")
                    
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "success" to true,
                            "ip" to ip,
                            "location" to "$city, $country",
                            "response" to body
                        ))
                    }
                } else {
                    ProxyStatistics.recordFailure()
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "success" to false,
                            "error" to "HTTP ${response.code}"
                        ))
                    }
                }
            } catch (e: Exception) {
                ProxyStatistics.recordFailure()
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to false,
                        "error" to (e.message ?: "Test failed")
                    ))
                }
            }
        }
    }

    private fun handleRequest(call: MethodCall, result: Result) {
        val url = call.argument<String>("url") ?: run {
            result.error("INVALID_ARGUMENT", "URL is required", null)
            return
        }
        
        val method = call.argument<String>("method") ?: "GET"
        val headers = call.argument<Map<String, String>>("headers")
        val body = call.argument<String>("body")
        
        val client = if (isConnected && proxyClient != null) proxyClient!! else normalClient!!
        
        scope.launch {
            try {
                ProxyStatistics.recordRequest(url)
                
                val requestBuilder = Request.Builder().url(url)
                
                headers?.forEach { (key, value) ->
                    requestBuilder.addHeader(key, value)
                }
                
                when (method) {
                    "POST" -> {
                        val mediaType = "application/json".toMediaType()
                        val requestBody = body?.toRequestBody(mediaType) ?: "".toRequestBody(mediaType)
                        requestBuilder.post(requestBody)
                    }
                    "PUT" -> {
                        val mediaType = "application/json".toMediaType()
                        val requestBody = body?.toRequestBody(mediaType) ?: "".toRequestBody(mediaType)
                        requestBuilder.put(requestBody)
                    }
                    "DELETE" -> requestBuilder.delete()
                    else -> requestBuilder.get()
                }
                
                val request = requestBuilder.build()
                val response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: ""
                
                if (response.isSuccessful) {
                    ProxyStatistics.recordSuccess(responseBody.length.toLong())
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "statusCode" to response.code,
                            "body" to responseBody,
                            "headers" to response.headers.toMultimap()
                        ))
                    }
                } else {
                    ProxyStatistics.recordFailure()
                    withContext(Dispatchers.Main) {
                        result.error("HTTP_ERROR", "HTTP ${response.code}", responseBody)
                    }
                }
            } catch (e: Exception) {
                ProxyStatistics.recordFailure()
                withContext(Dispatchers.Main) {
                    result.error("REQUEST_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleRpcRequest(call: MethodCall, result: Result) {
        val url = call.argument<String>("url") ?: run {
            result.error("INVALID_ARGUMENT", "URL is required", null)
            return
        }
        
        val method = call.argument<String>("method") ?: run {
            result.error("INVALID_ARGUMENT", "Method is required", null)
            return
        }
        
        val params = call.argument<List<Any>>("params") ?: emptyList()
        val id = call.argument<Int>("id") ?: 1
        
        val client = if (isConnected && proxyClient != null) proxyClient!! else normalClient!!
        
        scope.launch {
            try {
                ProxyStatistics.recordRequest(url)
                ProxyStatistics.recordRpcMethod(method)
                
                val requestBody = JSONObject().apply {
                    put("jsonrpc", "2.0")
                    put("method", method)
                    put("params", JSONArray(params))
                    put("id", id)
                }
                
                val mediaType = "application/json".toMediaType()
                val request = Request.Builder()
                    .url(url)
                    .post(requestBody.toString().toRequestBody(mediaType))
                    .addHeader("Content-Type", "application/json")
                    .build()
                
                val response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: ""
                
                if (response.isSuccessful) {
                    ProxyStatistics.recordSuccess(responseBody.length.toLong())
                    val jsonResponse = JSONObject(responseBody)
                    
                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "jsonrpc" to jsonResponse.optString("jsonrpc"),
                            "id" to jsonResponse.optInt("id"),
                            "result" to jsonResponse.opt("result"),
                            "error" to jsonResponse.optJSONObject("error")?.toString()
                        ))
                    }
                } else {
                    ProxyStatistics.recordFailure()
                    withContext(Dispatchers.Main) {
                        result.error("RPC_ERROR", "HTTP ${response.code}", responseBody)
                    }
                }
            } catch (e: Exception) {
                ProxyStatistics.recordFailure()
                withContext(Dispatchers.Main) {
                    result.error("RPC_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleGetStatistics(result: Result) {
        result.success(ProxyStatistics.getStatistics())
    }

    private fun handleResetStatistics(result: Result) {
        ProxyStatistics.reset()
        result.success(null)
    }

    private data class ProxyConfig(
        val host: String,
        val port: Int
    )
}

// Copy ProxyStatistics from the main app
object ProxyStatistics {
    private var requestCount = 0L
    private var successCount = 0L
    private var failureCount = 0L
    private var bytesTransferred = 0L
    private val rpcMethodCounts = mutableMapOf<String, Long>()
    
    fun recordRequest(url: String) {
        requestCount++
    }
    
    fun recordSuccess(bytes: Long = 0) {
        successCount++
        bytesTransferred += bytes
    }
    
    fun recordFailure() {
        failureCount++
    }
    
    fun recordRpcMethod(method: String) {
        rpcMethodCounts[method] = (rpcMethodCounts[method] ?: 0) + 1
    }
    
    fun getStatistics(): Map<String, Any> {
        return mapOf(
            "totalRequests" to requestCount,
            "successCount" to successCount,
            "failureCount" to failureCount,
            "bytesTransferred" to bytesTransferred,
            "topRpcMethods" to rpcMethodCounts.entries.sortedByDescending { it.value }.take(5)
                .map { mapOf("method" to it.key, "count" to it.value) }
        )
    }
    
    fun reset() {
        requestCount = 0
        successCount = 0
        failureCount = 0
        bytesTransferred = 0
        rpcMethodCounts.clear()
    }
}