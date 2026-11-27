#include <duckdb.hpp>

#include <cstdio>
#include <cstring>
#include <exception>
#include <string>

#ifdef ASHELL_DUCKDB
extern "C" FILE *ios_stdout(void);
extern "C" FILE *ios_stderr(void);
#define COMMAND extern "C" int duckdb_ios_main
#else
#define COMMAND int main
#endif

static void csv_field(FILE *out, const std::string &value) {
    if (value.find_first_of(",\"\r\n") == std::string::npos) {
        fwrite(value.data(), 1, value.size(), out);
        return;
    }
    fputc('"', out);
    for (unsigned char byte : value) {
        if (byte == '"') fputc('"', out);
        fputc(byte, out);
    }
    fputc('"', out);
}

COMMAND(int argc, char **argv) {
#ifdef ASHELL_DUCKDB
    FILE *out = ios_stdout(), *err = ios_stderr();
#else
    FILE *out = stdout, *err = stderr;
#endif
    if (argc == 2 && strcmp(argv[1], "--version") == 0) {
        return fprintf(out, "%s\n", duckdb::DuckDB::LibraryVersion()) < 0;
    }
    if (argc != 3 || strcmp(argv[1], "-c") != 0) {
        fputs("usage: duckdb -c SQL | duckdb --version\n", err);
        return 2;
    }

    try {
        duckdb::DBConfig config;
        config.SetOptionByName("threads", duckdb::Value::BIGINT(1));
        config.SetOptionByName("autoload_known_extensions", duckdb::Value::BOOLEAN(false));
        config.SetOptionByName("autoinstall_known_extensions", duckdb::Value::BOOLEAN(false));
        duckdb::DuckDB database(nullptr, &config);
        duckdb::Connection connection(database);
        auto result = connection.Query(argv[2]);
        if (result->HasError()) {
            fprintf(err, "duckdb: %s\n", result->GetError().c_str());
            return 1;
        }

        const auto columns = result->ColumnCount();
        for (duckdb::idx_t col = 0; col < columns; ++col) {
            if (col) fputc(',', out);
            csv_field(out, result->ColumnName(col));
        }
        if (columns) fputc('\n', out);
        const auto rows = result->RowCount();
        for (duckdb::idx_t row = 0; row < rows; ++row) {
            for (duckdb::idx_t col = 0; col < columns; ++col) {
                if (col) fputc(',', out);
                const auto value = result->GetValue(col, row);
                if (!value.IsNull()) csv_field(out, value.ToString());
            }
            fputc('\n', out);
        }
        return fflush(out) == EOF || ferror(out);
    } catch (const std::exception &error) {
        fprintf(err, "duckdb: %s\n", error.what());
        return 1;
    }
}
