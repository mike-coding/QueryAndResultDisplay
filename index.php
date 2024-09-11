<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-GLhlTQ8iRABdZLl6O3oVMWSktQOp6b7In1Zl3/Jr59b6EGGoI1aFkw7cmDA6j6gD" crossorigin="anonymous">
    <title>CS4400 Group9</title>
    <style>
        body {
            background-color: #fff;
            color: #333;
        }
        .card {
            background-color: #fff;
            border-color: #333;
        }
    </style> 
</head>
<body>
    <nav class="navbar navbar-dark navbar-expand-md bg-dark" data-bs-theme="dark">
        <div class="container-fluid">
          <a class="navbar-brand">ImmunoSys – An Influenza Vaccine Tracking System </a>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container-fluid d-flex flex-column justify-content-center" style="padding-right: 100px; padding-left: 100px;">
        <br>
        <div class="alert alert-dark text-center" role="alert" style="display: inline-block;">
            A project by Mike Wurth for CS:4400
        </div>
        <div class="query-container">
            <?php
            $mysqli = new mysqli("webdev.divms.uiowa.edu", "cs4400", "<passphrase omitted for privacy>", "cs4400");

            // Check connection
            if ($mysqli->connect_error) {
                die("Connection failed: " . $mysqli->connect_error);
            } else {
                // Define queries
                $queries = [
                    [
                        "query" => "SELECT 
                                        p.Name AS PatientName,
                                        CONCAT(b.Year, ' ', f.Formulation) AS VaccineType,
                                        a.Date AS VaccinationDate,
                                        a.AdverseEffectEvent AS AdverseEffects
                                    FROM 
                                        Appointments a
                                    JOIN 
                                        Patients p ON a.PatientId = p.PatientId
                                    JOIN 
                                        Batches b ON a.BatchId = b.BatchId
                                    JOIN 
                                        Formulations f ON b.Formulation = f.Formulation
                                    WHERE 
                                        a.Date < CURDATE() AND
                                        p.PatientId = 1
                                    ORDER BY 
                                        a.Date DESC;",
                        "description" => "Get vaccination history for patient with Id = 1"
                    ],
                    [
                        "query" => "SELECT
                                        t.Sex,
                                        AVG(t.TotalVaccinations) AS AverageVaccinations
                                    FROM(
                                        SELECT
                                            p.Sex,
                                            COUNT(*) AS TotalVaccinations
                                        FROM
                                            Appointments a
                                        JOIN 
                                            Patients p ON a.PatientId = p.PatientId
                                        WHERE 
                                            a.Date < CURDATE()
                                        GROUP BY
                                            p.PatientId, p.Sex) AS t
                                    GROUP BY t.Sex
                                    ORDER BY 
                                        AverageVaccinations DESC;",
                        "description" => "Get average number of vaccinations by sex"
                    ],
                    [
                        "query" => "SELECT
                                        DISTINCT CONCAT(b.Year, ' ', b.Formulation) AS VaccineType
                                    FROM 
                                        View_SimpleBatchInformation b
                                    JOIN
                                        Appointments a ON b.AppointmentId = a.AppointmentId
                                    WHERE
                                        a.AdverseEffectEvent <> 'None';",
                        "description" => "Get VaccineType (Year_Formulation) of vaccine batches associated with adverse effect events"
                    ],
                    [
                        "query" => "SELECT
                                        c.CenterName
                                    FROM 
                                        HealthCareCenters c
                                    JOIN
                                        Appointments a ON c.CenterId = a.CenterId
                                    WHERE
                                        a.Date<CURDATE()
                                    GROUP BY
                                        c.CenterId
                                    ORDER BY 
                                        COUNT(a.AppointmentId) DESC
                                    LIMIT 1;",
                        "description" => "Get the name of the health care center with the most (past) vaccination appointments"
                    ],
                    [
                        "query" => "SELECT
                                        p.Name AS PatientName,
                                        hcp.Name AS HealthCareProvider,
                                        a.Time,
                                        a.Date,
                                        c.CenterName,
                                        DATEDIFF(a.Date, CURDATE()) AS DaysUntilAppointment
                                    FROM
                                        Patients p
                                    JOIN
                                        Appointments a ON p.PatientId = a.PatientId
                                    JOIN
                                        HealthCareProviders hcp ON a.ProviderId = hcp.ProviderId
                                    JOIN
                                        HealthCareCenters c ON a.CenterId = c.CenterId
                                    WHERE
                                        a.Date > CURDATE() AND
                                        p.PatientId = 2;",
                        "description" => "Get information about upcoming appointment for patient with Id = 2"
                    ]
                ];

                $queryResults = [];
                foreach ($queries as $index => $queryData) {
                    $query = $queryData['query'];
                    $result = $mysqli->query($query);
                    if ($result) {
                        $rows = $result->fetch_all(MYSQLI_ASSOC);
                        $queryResults[] = [
                            'description' => $queryData['description'], 
                            'rows' => $rows,
                            'query' => $query 
                        ];
                        $result->free();
                    }
                }
                $mysqli->close();
                echo '<script type="application/json" id="queryData">' . json_encode($queryResults) . '</script>';}
            ?>
        </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js" integrity="sha384-w76AqPfDkMBDXo30jS1Sgez6pr3x5MlQ1ZAGC+nuZB+EYdgRZgiwxhTBTkF7CXvN" crossorigin="anonymous"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const queryData = JSON.parse(document.getElementById('queryData').textContent);
            queryData.forEach((item, index) => {
                const headers = item.rows.length > 0 ? Object.keys(item.rows[0]) : [];
                const queryResult = createTable(item.rows, headers);
                const queryAsText = createQueryAsText(item.query); 
                const queryRow = createQueryRow(index + 1, item.description, queryResult, queryAsText); 
                document.querySelector('.query-container').innerHTML += queryRow;
            });
        });

        function createQueryAsText(query) {
            if (typeof query !== 'string') {
                return `Unexpected type: ${typeof query}`; 
            }

            const keywords = ['SELECT', 'FROM', 'WHERE', 'JOIN', 'GROUP BY', 'ORDER BY', 'LIMIT', 'HAVING'];
            let formattedQuery = query;

            keywords.forEach(keyword => {
                const regex = new RegExp(`\\b${keyword}\\b`, 'g');
                formattedQuery = formattedQuery.replace(regex, `\n<b>${keyword}</b>`);
            });

            formattedQuery = formattedQuery.replace(/\b(ON|AS|DISTINCT)\b/g, `<b>$1</b>`);

            let depth = 0; 
            let lines = formattedQuery.split('\n');
            formattedQuery = lines.map(line => {
                let openingCount = (line.match(/\(/g) || []).length;
                let closingCount = (line.match(/\)/g) || []).length;

                if (closingCount > 0) depth -= closingCount;
                
                let indentation = '\t'.repeat(Math.max(depth, 0));
                let formattedLine = indentation + line;

                if (openingCount > 0) depth += openingCount;

                return formattedLine;
            }).join('\n');

            formattedQuery = formattedQuery.replace(/\n[ \t]+/g, '\n\t');

            formattedQuery = formattedQuery.replace(/\t\n/g, '');
            
            return formattedQuery;
        }

        function createTable(data, headers) {
            let table = '<table class="table table-striped" style="width: 100%;"><thead><tr>';
            const columnWidth = 100 / headers.length; // Calculate the width for each column based on the number of headers
            headers.forEach(header => {
                table += `<th style="width: ${columnWidth}%; text-align: center;">${header}</th>`; // Set each header to have equal width and center alignment
            });
            table += '</tr></thead><tbody>';
            data.forEach(row => {
                table += '<tr>';
                Object.values(row).forEach(cell => {
                    table += `<td style="text-align: center;">${cell}</td>`; // Center align each cell
                });
                table += '</tr>';
            });
            table += '</tbody></table>';
            return table;
        }

        function createQueryRow(queryNumber, queryDescription, queryResult, queryAsText) {
            return `
            <div class="row justify-content-center mb-5 mt-5">
                <div class="d-flex justify-content-center align-items-center">
                    <div class="text-left" style="width: 100%; font-size: 24px; padding-bottom: 20px;">
                        <b><u>Query ${queryNumber}:</u></b>
                        <span style="font-size: 16px; padding-left: 18px;">${queryDescription}</span>
                    </div>
                </div>
                <div class = "row alert alert-dark justify-content-center">
                    <div class="col-md-6 d-flex flex-column justify-content-center" style="height: 100%;">
                    <div class="container-fluid d-flex justify-content-center align-items-center" style="flex-grow: 1;">
                        <pre style="font-family: inherit; margin: 0; text-align: left;">${queryAsText}</pre>
                    </div>
                </div>
                    <div class="col-md-6">
                        <div class="row mb-2">
                            <div class="d-flex justify-content-center align-items-center">
                                <div class="text-center" style="width: 100%;">
                                    <b><u>Output Table:</u></b>
                                    <br>
                                </div>
                            </div>
                        </div>
                        <div class="container-fluid d-flex justify-content-center align-items-center">
                            <div class="alert alert-light" style="width: 100%;">
                                ${queryResult}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            `;
        }
    </script>
</body>
</html>