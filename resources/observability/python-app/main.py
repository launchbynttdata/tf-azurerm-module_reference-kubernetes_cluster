
from flask import Flask, request, make_response, jsonify
import os
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
import requests
import logging
from opentelemetry import trace

# Set up logging
logging.basicConfig(level=logging.INFO)
logging.getLogger('opentelemetry.exporter.otlp').setLevel(logging.INFO)


app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

port = os.environ.get('FLASK_PORT', '8080')
debug = os.environ.get('DEBUG', False)
enable_oltp_exporter = os.environ.get('ENABLE_OTLP_EXPORTER', True)
enable_azure_monitor_exporter = os.environ.get('ENABLE_AZURE_MONITOR_EXPORTER', False)


def get_header_from_flask_request(request, key):
    return request.headers.get_all(key)


def set_header_into_requests_request(request: requests.Request,
                                        key: str, value: str):
    request.headers[key] = value

@app.route('/')
def hello_world():
    headers = request.headers
    logging.info("Inside hello_world")
    logging.info(f"headers: {headers}")
    res = make_response(jsonify({"message": "Hello World"}))
    res.headers['Content-Type'] = 'application/json'
    res.headers['Access-Control-Allow-Origin'] = '*'
    return res


@app.route('/example')
def example_route():
    try:

        res = requests.get("http://httpbin.org/get")

        response = make_response(res.json())
        response.headers['Content-Type'] = 'application/json'
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response
    except Exception as e:
        logging.info(f"Exception: {e}")

        return "an error has occurred"


@app.route('/user/<username>')
def show_username(username):
    headers = request.headers
    logging.info("show username")
    logging.info(f"headers: {headers}")
    with tracer.start_as_current_span("show_username"):
        logging.info(f"username: {username}")
        with tracer.start_as_current_span("show_username_inner"):
            logging.info(f"child span")
    res = make_response(jsonify({"message": f"Hello World: {username}"}))
    res.headers['Content-Type'] = 'application/json'
    res.headers['Access-Control-Allow-Origin'] = '*'
    return res


if __name__ == '__main__':

    # Some backends need this to display a name for the service in the graph GUI
    resource = Resource(attributes={
        "service.name": "PythonRestService",
    })
    trace.set_tracer_provider(TracerProvider(resource=resource))

    if enable_oltp_exporter:
        # Set the env var OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="http://10.20.20.20:4317"
        if os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") is None:
            raise ValueError("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT env var is not set")
        is_insecure = os.environ.get('OTEL_EXPORTER_OTLP_INSECURE', True)

        otlp_exporter = OTLPSpanExporter(insecure=is_insecure)
        span_processor = BatchSpanProcessor(otlp_exporter)
        trace.get_tracer_provider().add_span_processor(span_processor)

    tracer = trace.get_tracer(__name__)
    if enable_azure_monitor_exporter:
        if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING") is None:
            raise ValueError("APPLICATIONINSIGHTS_CONNECTION_STRING env var is not set")

        instrumentation_options = {"azure_sdk": {"enabled": False}, "flask": {"enabled": True},
                                   "django": {"enabled": False}}
        configure_azure_monitor(instrumentation_options=instrumentation_options, disable_metrics=True, disable_logging=True)

    app.run(host="0.0.0.0", port=port, debug=debug)
