FROM python:3.11


WORKDIR /app

COPY requirements.txt requirements.txt
COPY main.py app.py

RUN pip install -r requirements.txt

CMD ["python", "-u", "app.py"]
