from flask import Flask
import os
import psycopg2

app = Flask(__name__)

@app.route('/')
def index():
    db_str = "host={} dbname={} user={} password={}".format(
            os.environ["MDB_HOST"], os.environ["MDB_DB"],
            os.environ["MDB_USER"], os.environ["MDB_PASS"])
    with psycopg2.connect(db_str) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT content, date FROM testcounter ORDER BY id desc LIMIT %s", (10, ))

            return '\n'.join(["{}: {}".format(date, content) for (content, date) in cursor])

def main():
    app.run(host='0.0.0.0')

if __name__ == '__main__':
    main()
