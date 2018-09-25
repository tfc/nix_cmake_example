from flask import Flask
import psycopg2

app = Flask(__name__)

@app.route('/')
def index():
    with psycopg2.connect("host=127.0.0.1 dbname=testdb user=testuser password=testuser") as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT content, date FROM testcounter ORDER BY id desc LIMIT %s", (10, ))

            return '\n'.join(["{}: {}".format(date, content) for (content, date) in cursor])

def main():
    app.run(host='0.0.0.0')

if __name__ == '__main__':
    main()
