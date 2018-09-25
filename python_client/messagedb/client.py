import os
import psycopg2

def main():
    db_str = "host={} dbname={} user={} password={}".format(
            os.environ["MDB_HOST"], os.environ["MDB_DB"],
            os.environ["MDB_USER"], os.environ["MDB_PASS"])
    with psycopg2.connect(db_str) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT content, date FROM testcounter ORDER BY id desc LIMIT %s;", (10, ))

            for (content, date) in cursor:
                print("{}: {}".format(date, content))

if __name__ == "__main__":
    main()
