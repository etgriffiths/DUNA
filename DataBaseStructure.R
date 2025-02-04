library(sqldf)
library(stringr)

dbname="DK_NoiseMonitoringMetatadata_v5.sqlite"

##Create your SQLite database and Station Table

db <- dbConnect(SQLite(), dbname=dbname)



#https://datasciencesphere.com/database/sqlite-database-r/

#  First create equipment tables

dbSendQuery(conn = db,
            'CREATE TABLE Logger_Table(
            loggerUID VARCHAR(50) PRIMARY KEY,
            Brand TEXT,
            Type TEXT,
            unitID TEXT,
            purchasedBy TEXT,
            unitStatus LOGICAL,
            clipLevel REAL,
            updateDate VARCHAR(30),
            Notes TEXT)')

dbSendQuery(conn = db,
            'CREATE TABLE Releaser_Table(
            releaserUID VARCHAR(50) PRIMARY KEY,
            Type TEXT,
            Brand TEXT,
            unitID TEXT,
            purchasedBy TEXT,
            unitStatus LOGICAL,
            updateDate VARCHAR(30),
            Notes TEXT)')

dbSendQuery(conn = db,
            'CREATE TABLE Satellite_Table(
            satUID VARCHAR(50) PRIMARY KEY,
            satLocation varchar(10),
            Type TEXT,
            Brand TEXT,
            unitID TEXT,
            purchasedBy TEXT,
            unitStatus LOGICAL,
            updateDate VARCHAR(30),
            Notes TEXT)')



# Calibration Tables

dbSendQuery(conn = db,
            'CREATE TABLE Logger_Cal_Table(
            calUID VARCHAR(50) PRIMARY KEY,
            loggerUID VARCHAR(50),
            hydrophoneID VARCHAR(50),
            calibrationLocation TEXT,
            calibrationDate VARCHAR(30),
            Operator VARCHAR (5),
            Model TEXT,
            ID TEXT,
            SourceModel TEXT,
            SourceSerial TEXT,
            SourceFrequency TEXT,
            SourceCoupler TEXT,
            SourceLevel TEXT,
            ReferenceModel TEXT,
            ReferenceSerial TEXT,
            ReferenceVPa REAL,
            VoltsRMS REAL,
            Calibration_HighGain TEXT,
            Calibration_LowGain TEXT,
            Sensitivity TEXT,
            CalibrationTone TEXT,
            CalibrationToneLevel TEXT,
            clipLevel REAL,
            updateDate VARCHAR(30),
            Notes TEXT,
            toneRange VARCHAR(30),
            CaliFile VARCHAR(300),
            FOREIGN KEY(loggerUID) REFERENCES Logger_Table (loggerUID)
            )')

#Station Table

dbSendQuery(conn = db,
            'CREATE TABLE Station_Table(
            station VARCHAR(10) PRIMARY KEY,
            location TEXT,
            stationLat REAL,
            stationLon REAL,
            Depth REAL,
            updateDate VARCHAR(30)
            )')

# Deployment Table
# 

dbSendQuery(conn = db,
            'CREATE TABLE Deployment_Table(
            Deployment_ID VARCHAR(10) PRIMARY KEY,
            station VARCHAR(10),
            Datetime_Deployment TEXT,
            mooringLat REAL,
            mooringLon REAL,
            Deployed_by TEXT,
            releaserUID VARCHAR(50),
            loggerUID VARCHAR(50),
            mooringSatUID VARCHAR(50),
            mooringOut LOGICAL,
            mooringLost TEXT,
            Datetime_Retrieval TEXT,
            Datetime_EndUsableData TEXT,
            EnteredBy TEXT,
            good LOGICAL,
            Comments TEXT,
            FOREIGN KEY(mooringSatUID) REFERENCES Satellite_Table (satUID),
            FOREIGN KEY(releaserUID) REFERENCES Releaser_Table (releaserUID),
            FOREIGN KEY(loggerUID) REFERENCES Logger_Table (loggerUID),
            FOREIGN KEY(station) REFERENCES Station_Table(station)
            )')


dbSendQuery(conn = db,
            'CREATE TABLE Logger_Data_Table(
            LoggerDataUID VARCHAR(10) PRIMARY KEY,
            Deployment_ID VARCHAR(50),
            loggerUID VARCHAR(50),
            dataPath TEXT,
            DTstart TEXT,
            DTend TEXT,
            calUID VARCHAR(50),
            FOREIGN KEY(loggerUID) REFERENCES Logger_Table (loggerUID),
            FOREIGN KEY(Deployment_ID) REFERENCES Deployment_Table(Deployment_ID),
            FOREIGN KEY(calUID) REFERENCES Logger_Cal_Table (calUID)
)')


dbSendQuery(conn = db,
            'CREATE TABLE Logger_Analysis_Table(
            LoggerAnalysisUID VARCHAR(10) PRIMARY KEY,
            LoggerDataUID VARCHAR(10),
            Deployment_ID VARCHAR(50),
            loggerUID VARCHAR(50),
            analysisType TEXT,
            resultsPath TEXT,
            wavFiles TEXT,
            script TEXT,
            processingDate TEXT,
            dataFile TEXT,
            FOREIGN KEY(LoggerDataUID) REFERENCES Logger_Data_Table(LoggerDataUID),
            FOREIGN KEY(loggerUID) REFERENCES Logger_Table (loggerUID),
            FOREIGN KEY(Deployment_ID) REFERENCES Deployment_Table(Deployment_ID))')



dbDisconnect(db)


