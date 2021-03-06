USE [master]
GO
/****** Object:  Database [PWHistory]    Script Date: 31/03/2018 6:01:33 PM ******/
CREATE DATABASE [PWHistory]
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [PWHistory].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [PWHistory] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [PWHistory] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [PWHistory] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [PWHistory] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [PWHistory] SET ARITHABORT OFF 
GO
ALTER DATABASE [PWHistory] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [PWHistory] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [PWHistory] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [PWHistory] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [PWHistory] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [PWHistory] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [PWHistory] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [PWHistory] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [PWHistory] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [PWHistory] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [PWHistory] SET ALLOW_SNAPSHOT_ISOLATION ON 
GO
ALTER DATABASE [PWHistory] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [PWHistory] SET READ_COMMITTED_SNAPSHOT ON 
GO
ALTER DATABASE [PWHistory] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [PWHistory] SET  MULTI_USER 
GO
ALTER DATABASE [PWHistory] SET DB_CHAINING OFF 
GO
ALTER DATABASE [PWHistory] SET ENCRYPTION ON
GO
ALTER DATABASE [PWHistory] SET QUERY_STORE = ON
GO
ALTER DATABASE [PWHistory] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 100, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO)
GO
USE [PWHistory]
GO
ALTER DATABASE SCOPED CONFIGURATION SET IDENTITY_CACHE = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET OPTIMIZE_FOR_AD_HOC_WORKLOADS = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = ON;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = PRIMARY;
GO
ALTER DATABASE SCOPED CONFIGURATION SET XTP_PROCEDURE_EXECUTION_STATISTICS = OFF;
GO
ALTER DATABASE SCOPED CONFIGURATION SET XTP_QUERY_EXECUTION_STATISTICS = OFF;
GO
USE [PWHistory]
GO
/****** Object:  Table [dbo].[forecasts]    Script Date: 31/03/2018 6:01:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[forecasts](
	[EstimateDateTimeUTC] [datetime] NOT NULL,
	[EstimateDateTimeLocal] [datetime] NOT NULL,
	[EnergyEstimate] [numeric](19, 15) NOT NULL,
	[EstimateDateLocal]  AS (CONVERT([date],[EstimateDateTimeLocal])) PERSISTED NOT NULL,
	[OriginalEnergyEstimate] [numeric](19, 15) NOT NULL,
 CONSTRAINT [PK_forecasts_EstimateDateTimeUTC] PRIMARY KEY CLUSTERED 
(
	[EstimateDateTimeUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[fnGetDailyPVForecast]    Script Date: 31/03/2018 6:01:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnGetDailyPVForecast](@TargetDate DATE = NULL)
	RETURNS TABLE
AS
	RETURN (
		WITH StartEndForecasts AS (
			SELECT	FS.EstimateDateTimeLocal AS PeriodStart
			,		FE.EstimateDateTimeLocal AS PeriodEnd
			,		FS.EnergyEstimate * 2 AS PowerStart
			,		FE.EnergyEstimate * 2 AS PowerEnd
			FROM forecasts AS FE
			JOIN forecasts as FS 
				ON DATEADD(MINUTE, -30, FE.EstimateDateTimeUTC) = FS.EstimateDateTimeUTC
			WHERE	FE.EstimateDateLocal = ISNULL(@TargetDate, CAST(CONVERT(DATETIMEOFFSET, GETDATE()) AT TIME ZONE 'AUS Eastern Standard Time' AS DATE))
			)
		,	NonZeroForecasts AS (
			SELECT	DATEADD(MINUTE, Minutes, PeriodStart) AS PeriodStartTime
			,		(PowerStart + ((PowerEnd - PowerStart) * (CAST(Ratio AS DECIMAL(4,2)) / 24.0))) AS PeriodPower
			FROM	StartEndForecasts
			CROSS APPLY (VALUES (0,0), (5,1), (10,5), (15,12), (20,19), (25,23))
					AS Offset (Minutes, Ratio)
			WHERE		(PowerStart <> 0 OR PowerEnd <> 0)
			)
		,	LastForecast AS (
			SELECT DATEADD(MINUTE, 5, MAX(PeriodStartTime)) AS PeriodStartTime
			,		0 AS PeriodPower
			FROM	NonZeroForecasts
			)
		SELECT	PeriodStartTime, PeriodPower
		FROM	NonZeroForecasts 
		UNION
		SELECT	*
		FROM	LastForecast
	)
GO
/****** Object:  Table [dbo].[battery]    Script Date: 31/03/2018 6:01:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[battery](
	[last_communication_time] [datetime] NOT NULL,
	[instant_power] [numeric](20, 15) NOT NULL,
	[instant_reactive_power] [numeric](20, 15) NOT NULL,
	[instant_apparent_power] [numeric](20, 15) NOT NULL,
	[frequency] [numeric](17, 15) NOT NULL,
	[energy_exported] [numeric](20, 10) NOT NULL,
	[energy_imported] [numeric](20, 10) NOT NULL,
	[instant_average_voltage] [numeric](20, 15) NOT NULL,
	[instant_total_current] [numeric](20, 15) NOT NULL,
	[i_a_current] [int] NOT NULL,
	[i_b_current] [int] NOT NULL,
	[i_c_current] [int] NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_battery] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[busway]    Script Date: 31/03/2018 6:01:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[busway](
	[last_communication_time] [datetime] NOT NULL,
	[instant_power] [numeric](20, 15) NOT NULL,
	[instant_reactive_power] [numeric](20, 15) NOT NULL,
	[instant_apparent_power] [numeric](20, 15) NOT NULL,
	[frequency] [numeric](17, 15) NOT NULL,
	[energy_exported] [numeric](20, 10) NOT NULL,
	[energy_imported] [numeric](20, 10) NOT NULL,
	[instant_average_voltage] [numeric](20, 15) NOT NULL,
	[instant_total_current] [numeric](20, 15) NOT NULL,
	[i_a_current] [int] NOT NULL,
	[i_b_current] [int] NOT NULL,
	[i_c_current] [int] NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_busway] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CompactObs]    Script Date: 31/03/2018 6:01:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CompactObs](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ObservationDateTimeUTC] [datetime] NOT NULL,
	[ObservationDateTimeLocal] [datetime] NOT NULL,
	[POC] [numeric](6, 3) NOT NULL,
	[BattVoltage] [numeric](6, 3) NOT NULL,
	[GridVoltage] [numeric](6, 3) NOT NULL,
	[Battery] [numeric](7, 3) NOT NULL,
	[Grid] [numeric](7, 3) NOT NULL,
	[Solar] [numeric](7, 3) NOT NULL,
	[Load] [numeric](7, 3) NOT NULL,
 CONSTRAINT [PK_CompactObs_ID] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [UK_CompactObs_UTC]    Script Date: 31/03/2018 6:01:35 PM ******/
CREATE UNIQUE CLUSTERED INDEX [UK_CompactObs_UTC] ON [dbo].[CompactObs]
(
	[ObservationDateTimeUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CompactObsByMinute]    Script Date: 31/03/2018 6:01:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CompactObsByMinute](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ObservationDateTimeUTC] [smalldatetime] NOT NULL,
	[ObservationDateTimeLocal] [smalldatetime] NOT NULL,
	[SOC] [numeric](6, 3) NOT NULL,
	[BattVoltage] [numeric](6, 3) NOT NULL,
	[GridVoltage] [numeric](6, 3) NOT NULL,
	[Battery] [numeric](7, 3) NOT NULL,
	[Grid] [numeric](7, 3) NOT NULL,
	[Solar] [numeric](7, 3) NOT NULL,
	[Load] [numeric](7, 3) NOT NULL,
	[Observations] [tinyint] NOT NULL,
 CONSTRAINT [PK_CompactObsByMinute_ID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[frequency]    Script Date: 31/03/2018 6:01:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[frequency](
	[last_communication_time] [datetime] NOT NULL,
	[instant_power] [numeric](20, 15) NOT NULL,
	[instant_reactive_power] [numeric](20, 15) NOT NULL,
	[instant_apparent_power] [numeric](20, 15) NOT NULL,
	[frequency] [numeric](17, 15) NOT NULL,
	[energy_exported] [numeric](20, 10) NOT NULL,
	[energy_imported] [numeric](20, 10) NOT NULL,
	[instant_average_voltage] [numeric](20, 15) NOT NULL,
	[instant_total_current] [numeric](20, 15) NOT NULL,
	[i_a_current] [int] NOT NULL,
	[i_b_current] [int] NOT NULL,
	[i_c_current] [int] NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_frequency] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[load]    Script Date: 31/03/2018 6:01:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[load](
	[last_communication_time] [datetime] NOT NULL,
	[instant_power] [numeric](20, 15) NOT NULL,
	[instant_reactive_power] [numeric](20, 15) NOT NULL,
	[instant_apparent_power] [numeric](20, 15) NOT NULL,
	[frequency] [numeric](17, 15) NOT NULL,
	[energy_exported] [numeric](20, 10) NOT NULL,
	[energy_imported] [numeric](20, 10) NOT NULL,
	[instant_average_voltage] [numeric](20, 15) NOT NULL,
	[instant_total_current] [numeric](20, 15) NOT NULL,
	[i_a_current] [int] NOT NULL,
	[i_b_current] [int] NOT NULL,
	[i_c_current] [int] NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_load] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[observations]    Script Date: 31/03/2018 6:01:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[observations](
	[ObservationDateTimeUTC] [datetime] NOT NULL,
	[ObservationDateTimeLocal] [datetime] NOT NULL,
	[ObservationID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_observations] PRIMARY KEY NONCLUSTERED 
(
	[ObservationDateTimeUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [IX_ObservationDateTimeLocal]    Script Date: 31/03/2018 6:01:37 PM ******/
CREATE CLUSTERED INDEX [IX_ObservationDateTimeLocal] ON [dbo].[observations]
(
	[ObservationDateTimeLocal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[site]    Script Date: 31/03/2018 6:01:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[site](
	[last_communication_time] [datetime] NOT NULL,
	[instant_power] [numeric](20, 15) NOT NULL,
	[instant_reactive_power] [numeric](20, 15) NOT NULL,
	[instant_apparent_power] [numeric](20, 15) NOT NULL,
	[frequency] [numeric](17, 15) NOT NULL,
	[energy_exported] [numeric](20, 10) NOT NULL,
	[energy_imported] [numeric](20, 10) NOT NULL,
	[instant_average_voltage] [numeric](20, 15) NOT NULL,
	[instant_total_current] [numeric](20, 15) NOT NULL,
	[i_a_current] [int] NOT NULL,
	[i_b_current] [int] NOT NULL,
	[i_c_current] [int] NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_site] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[sitemaster]    Script Date: 31/03/2018 6:01:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[sitemaster](
	[running] [varchar](50) NOT NULL,
	[uptime] [varchar](50) NOT NULL,
	[connected_to_tesla] [varchar](50) NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_sitemaster] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[soc]    Script Date: 31/03/2018 6:01:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[soc](
	[state_of_charge] [numeric](18, 15) NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_soc] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[solar]    Script Date: 31/03/2018 6:01:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[solar](
	[last_communication_time] [datetime] NOT NULL,
	[instant_power] [numeric](20, 15) NOT NULL,
	[instant_reactive_power] [numeric](20, 15) NOT NULL,
	[instant_apparent_power] [numeric](20, 15) NOT NULL,
	[frequency] [numeric](17, 15) NOT NULL,
	[energy_exported] [numeric](20, 10) NOT NULL,
	[energy_imported] [numeric](20, 10) NOT NULL,
	[instant_average_voltage] [numeric](20, 15) NOT NULL,
	[instant_total_current] [numeric](20, 15) NOT NULL,
	[i_a_current] [int] NOT NULL,
	[i_b_current] [int] NOT NULL,
	[i_c_current] [int] NOT NULL,
	[ObservationID] [int] NOT NULL,
 CONSTRAINT [PK_solar] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [IX_CompactObs_Local]    Script Date: 31/03/2018 6:01:39 PM ******/
CREATE NONCLUSTERED INDEX [IX_CompactObs_Local] ON [dbo].[CompactObs]
(
	[ObservationDateTimeLocal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_forecasts_EstimateDateLocal]    Script Date: 31/03/2018 6:01:39 PM ******/
CREATE NONCLUSTERED INDEX [IX_forecasts_EstimateDateLocal] ON [dbo].[forecasts]
(
	[EstimateDateLocal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [UK_observations]    Script Date: 31/03/2018 6:01:39 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UK_observations] ON [dbo].[observations]
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[battery]  WITH CHECK ADD  CONSTRAINT [FK_battery_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[battery] CHECK CONSTRAINT [FK_battery_observations]
GO
ALTER TABLE [dbo].[busway]  WITH CHECK ADD  CONSTRAINT [FK_busway_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[busway] CHECK CONSTRAINT [FK_busway_observations]
GO
ALTER TABLE [dbo].[frequency]  WITH CHECK ADD  CONSTRAINT [FK_frequency_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[frequency] CHECK CONSTRAINT [FK_frequency_observations]
GO
ALTER TABLE [dbo].[load]  WITH CHECK ADD  CONSTRAINT [FK_load_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[load] CHECK CONSTRAINT [FK_load_observations]
GO
ALTER TABLE [dbo].[site]  WITH CHECK ADD  CONSTRAINT [FK_site_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[site] CHECK CONSTRAINT [FK_site_observations]
GO
ALTER TABLE [dbo].[sitemaster]  WITH CHECK ADD  CONSTRAINT [FK_sitemaster_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[sitemaster] CHECK CONSTRAINT [FK_sitemaster_observations]
GO
ALTER TABLE [dbo].[soc]  WITH CHECK ADD  CONSTRAINT [FK_soc_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[soc] CHECK CONSTRAINT [FK_soc_observations]
GO
ALTER TABLE [dbo].[solar]  WITH CHECK ADD  CONSTRAINT [FK_solar_observations] FOREIGN KEY([ObservationID])
REFERENCES [dbo].[observations] ([ObservationID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[solar] CHECK CONSTRAINT [FK_solar_observations]
GO
/****** Object:  StoredProcedure [dbo].[spAggregateToMinute]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spAggregateToMinute] AS

BEGIN

	DECLARE @SearchDateTime SMALLDATETIME;

	SELECT @SearchDateTime = DATEADD(MINUTE, -10, MAX(ObservationDateTimeUTC)) FROM CompactObsByMinute;

	MERGE PWHistory.dbo.CompactObsByMinute AS ByMin
	USING (   SELECT   TOP 100 PERCENT CAST(ObservationDateTimeUTC AS SMALLDATETIME) AS ObservationDateTimeUTC
			  ,        CAST(ObservationDateTimeLocal AS SMALLDATETIME)               AS ObservationDateTimeLocal
			  ,        AVG (POC)                                                     AS SOC
			  ,        AVG (BattVoltage)                                             AS BattVoltage
			  ,        AVG (GridVoltage)                                             AS GridVoltage
			  ,        AVG (Battery)                                                 AS Battery
			  ,        AVG (Grid)                                                    AS Grid
			  ,        AVG (Solar)                                                   AS Solar
			  ,        AVG (Load)                                                    AS Load
			  ,        COUNT (*)                                                     AS Observations
			  FROM     PWHistory.dbo.CompactObs
			  WHERE    CAST(ObservationDateTimeUTC AS SMALLDATETIME) >= @SearchDateTime
			  GROUP BY CAST(ObservationDateTimeUTC AS SMALLDATETIME)
			  ,        CAST(ObservationDateTimeLocal AS SMALLDATETIME)
			  ORDER BY 1
		  ) AS RawObs
	ON RawObs.ObservationDateTimeUTC = ByMin.ObservationDateTimeUTC
	AND RawObs.ObservationDateTimeLocal = ByMin.ObservationDateTimeLocal
	WHEN MATCHED THEN UPDATE SET SOC = RawObs.SOC
					  ,          BattVoltage = RawObs.BattVoltage
					  ,          GridVoltage = RawObs.GridVoltage
					  ,          Battery = RawObs.Battery
					  ,          Grid = RawObs.Grid
					  ,          Solar = RawObs.Solar
					  ,          Load = RawObs.Load
					  ,          Observations = RawObs.Observations
	WHEN NOT MATCHED
		THEN INSERT (   ObservationDateTimeUTC
					,   ObservationDateTimeLocal
					,   SOC
					,   BattVoltage
					,   GridVoltage
					,   Battery
					,   Grid
					,   Solar
					,   Load
					,   Observations
					)
			 VALUES (RawObs.ObservationDateTimeUTC, RawObs.ObservationDateTimeLocal, RawObs.SOC, RawObs.BattVoltage, RawObs.GridVoltage, RawObs.Battery, RawObs.Grid, RawObs.Solar, RawObs.Load, RawObs.Observations);
END
GO
/****** Object:  StoredProcedure [dbo].[spAggregateToMinuteAll]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spAggregateToMinuteAll]
AS
BEGIN
	MERGE PWHistory.dbo.CompactObsByMinute AS ByMin
	USING (   SELECT   TOP 100 PERCENT CAST(ObservationDateTimeUTC AS SMALLDATETIME) AS ObservationDateTimeUTC
			  ,        CAST(ObservationDateTimeLocal AS SMALLDATETIME)               AS ObservationDateTimeLocal
			  ,        AVG (POC)                                                     AS SOC
			  ,        AVG (BattVoltage)                                             AS BattVoltage
			  ,        AVG (GridVoltage)                                             AS GridVoltage
			  ,        AVG (Battery)                                                 AS Battery
			  ,        AVG (Grid)                                                    AS Grid
			  ,        AVG (Solar)                                                   AS Solar
			  ,        AVG (Load)                                                    AS Load
			  ,        COUNT (*)                                                     AS Observations
			  FROM     PWHistory.dbo.CompactObs
			  GROUP BY CAST(ObservationDateTimeUTC AS SMALLDATETIME)
			  ,        CAST(ObservationDateTimeLocal AS SMALLDATETIME)
			  ORDER BY 1
		  ) AS RawObs
	ON RawObs.ObservationDateTimeUTC = ByMin.ObservationDateTimeUTC
	AND RawObs.ObservationDateTimeLocal = ByMin.ObservationDateTimeLocal
	WHEN MATCHED THEN UPDATE SET SOC = RawObs.SOC
					  ,          BattVoltage = RawObs.BattVoltage
					  ,          GridVoltage = RawObs.GridVoltage
					  ,          Battery = RawObs.Battery
					  ,          Grid = RawObs.Grid
					  ,          Solar = RawObs.Solar
					  ,          Load = RawObs.Load
					  ,          Observations = RawObs.Observations
	WHEN NOT MATCHED
		THEN INSERT (   ObservationDateTimeUTC
					,   ObservationDateTimeLocal
					,   SOC
					,   BattVoltage
					,   GridVoltage
					,   Battery
					,   Grid
					,   Solar
					,   Load
					,   Observations
					)
			 VALUES (RawObs.ObservationDateTimeUTC, RawObs.ObservationDateTimeLocal, RawObs.SOC, RawObs.BattVoltage, RawObs.GridVoltage, RawObs.Battery, RawObs.Grid, RawObs.Solar, RawObs.Load, RawObs.Observations);
END
GO
/****** Object:  StoredProcedure [dbo].[spElapsedStats]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spElapsedStats]
(
    @StartTime DATETIME,
    @EndTime DATETIME
)
AS
BEGIN

    /*


Testing
-------

EXEC spElapsedStats '2017-11-28', '2017-11-28 06:00:00.000'

*/

    DECLARE @StartObsID INT;
    DECLARE @EndObsID INT;
    DECLARE @BattExpStart INT;
    DECLARE @BattExpEnd INT;
    DECLARE @BattImpStart INT;
    DECLARE @BattImpEnd INT;
    DECLARE @LoadExpStart INT;
    DECLARE @LoadExpEnd INT;
    DECLARE @LoadImpStart INT;
    DECLARE @LoadImpEnd INT;
    DECLARE @SolarExpStart INT;
    DECLARE @SolarExpEnd INT;
    DECLARE @SolarImpStart INT;
    DECLARE @SolarImpEnd INT;
    DECLARE @GridExpStart INT;
    DECLARE @GridExpEnd INT;
    DECLARE @GridImpStart INT;
    DECLARE @GridImpEnd INT;
    DECLARE @SOCStart NUMERIC(6, 3);
    DECLARE @SOCEnd NUMERIC(6, 3);


    SELECT TOP 1
        @StartObsID = ObservationID
    FROM dbo.observations
    WHERE ObservationDateTimeLocal
    BETWEEN @StartTime AND @EndTime
    ORDER BY ObservationDateTimeLocal;

    SELECT TOP 1
        @EndObsID = ObservationID
    FROM dbo.observations
    WHERE ObservationDateTimeLocal
    BETWEEN @StartTime AND @EndTime
    ORDER BY ObservationDateTimeLocal DESC;


    SELECT TOP 1
        @BattExpStart = energy_exported,
        @BattImpStart = energy_imported
    FROM dbo.battery
    WHERE ObservationID = @StartObsID;

    SELECT @BattExpEnd = energy_exported,
           @BattImpEnd = energy_imported
    FROM dbo.battery
    WHERE ObservationID = @EndObsID;


    SELECT TOP 1
        @SolarExpStart = energy_exported,
        @SolarImpStart = energy_imported
    FROM dbo.solar
    WHERE ObservationID = @StartObsID;

    SELECT TOP 1
        @SolarExpEnd = energy_exported,
        @SolarImpEnd = energy_imported
    FROM dbo.solar
    WHERE ObservationID = @EndObsID;


    SELECT TOP 1
        @GridExpStart = energy_exported,
        @GridImpStart = energy_imported
    FROM dbo.site
    WHERE ObservationID = @StartObsID;

    SELECT TOP 1
        @GridExpEnd = energy_exported,
        @GridImpEnd = energy_imported
    FROM dbo.site
    WHERE ObservationID = @EndObsID;


    SELECT TOP 1
        @LoadExpStart = energy_exported,
        @LoadImpStart = energy_imported
    FROM dbo.load
    WHERE ObservationID = @StartObsID;
    SELECT TOP 1
        @LoadExpEnd = energy_exported,
        @LoadImpEnd = energy_imported
    FROM dbo.load
    WHERE ObservationID = @EndObsID;


    SELECT TOP 1
        @SOCStart = state_of_charge
    FROM dbo.soc
    WHERE ObservationID = @StartObsID;

    SELECT TOP 1
        @SOCEnd = state_of_charge
    FROM dbo.soc
    WHERE ObservationID = @EndObsID;

    WITH BaseResults
    AS (SELECT @BattExpStart - @BattExpEnd AS BattExp,
               @BattImpEnd - @BattImpStart AS BattImp,
               @LoadExpStart - @LoadExpEnd AS LoadExp,
               @LoadImpEnd - @LoadImpStart AS LoadImp,
               @GridExpStart - @GridExpEnd AS GridExp,
               @GridImpEnd - @GridImpStart AS GridImp,
               @SolarExpStart - @SolarExpEnd AS SolarExp,
               @SolarImpEnd - @SolarImpStart AS SolarImp,
               @SOCEnd - @SOCStart AS SOC),
         InterimResults
    AS (SELECT BattExp,
               BattImp,
               BattExp + BattImp AS BattNet,
               LoadExp,
               LoadImp,
               LoadExp + LoadImp AS LoadNet,
               GridExp,
               GridImp,
               GridExp + GridImp AS GridNet,
               SolarExp,
               SolarImp,
               SolarExp + SolarImp AS SolarNet,
               SOC,
               SOC * 140 AS RawBattNet
        FROM BaseResults)
    SELECT BattExp,
           BattImp,
           BattNet,
           LoadExp,
           LoadImp,
           LoadNet,
           GridExp,
           GridImp,
           GridNet,
           SolarExp,
           SolarImp,
           SolarNet,
           SOC,
           RawBattNet,
           RawBattNet - BattNet AS BattLosses,
           CAST(BattNet / RawBattNet * CAST(100 AS DECIMAL(5, 2)) AS DECIMAL(5, 2)) AS BattEfficiency
    FROM InterimResults;
END;

GO
/****** Object:  StoredProcedure [dbo].[spGet5MinuteAverages]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spGet5MinuteAverages] (@Now AS DATETIME)
AS
BEGIN
    /*

Testing
-------

EXEC spGet5MinuteAverages '2018-03-29 07:20:01'
EXEC spGet5MinuteAverages '2018-03-30 12:20:00'
EXEC spGet5MinuteAverages '2018-03-31 12:25:59'

*/

    DECLARE @StartDate AS SMALLDATETIME = DATEADD(SECOND, -60 - DATEPART(SECOND, @Now), @Now);
    SET @StartDate = DATEADD(MINUTE, (-5 - DATEPART(MINUTE, @StartDate) % 5), @StartDate);
    DECLARE @EndDate AS SMALLDATETIME = DATEADD(MINUTE, 5, @StartDate);
	WITH FiveMinObs AS
	(	SELECT	ObservationID    
		FROM	Observations WITH(INDEX(IX_ObservationDateTimeLocal))
		WHERE	ObservationDateTimeLocal BETWEEN @StartDate AND @EndDate
	) 
    SELECT CONVERT(VARCHAR(8), @EndDate, 112) AS livedate,
           CONVERT(VARCHAR(5), @EndDate, 108) AS livetime,
           CAST(AVG(B.instant_power) AS DECIMAL(18, 3)) AS battery_instant_power,
           CAST(AVG(B.instant_reactive_power) AS DECIMAL(18, 3)) AS battery_instant_reactive_power,
           CAST(AVG(B.instant_apparent_power) AS DECIMAL(18, 3)) AS battery_instant_apparent_power,
           CAST(AVG(B.frequency) AS DECIMAL(18, 3)) AS battery_frequency,
           CAST(AVG(B.energy_exported) AS DECIMAL(18, 3)) AS battery_energy_exported,
           CAST(AVG(B.energy_imported) AS DECIMAL(18, 3)) AS battery_energy_imported,
           CAST(AVG(B.instant_average_voltage) AS DECIMAL(18, 3)) AS battery_instant_average_voltage,
           CAST(AVG(B.instant_total_current) AS DECIMAL(18, 3)) AS battery_instant_total_current,
           CAST(AVG(B.i_a_current) AS DECIMAL(18, 3)) AS battery_i_a_current,
           CAST(AVG(B.i_b_current) AS DECIMAL(18, 3)) AS battery_i_b_current,
           CAST(AVG(B.i_c_current) AS DECIMAL(18, 3)) AS battery_i_c_current,
           CAST(AVG(S.instant_power) AS DECIMAL(18, 3)) AS site_instant_power,
           CAST(AVG(S.instant_reactive_power) AS DECIMAL(18, 3)) AS site_instant_reactive_power,
           CAST(AVG(S.instant_apparent_power) AS DECIMAL(18, 3)) AS site_instant_apparent_power,
           CAST(AVG(S.frequency) AS DECIMAL(18, 3)) AS site_frequency,
           CAST(AVG(S.energy_exported) AS DECIMAL(18, 3)) AS site_energy_exported,
           CAST(AVG(S.energy_imported) AS DECIMAL(18, 3)) AS site_energy_imported,
           CAST(AVG(S.instant_average_voltage) AS DECIMAL(18, 3)) AS site_instant_average_voltage,
           CAST(AVG(S.instant_total_current) AS DECIMAL(18, 3)) AS site_instant_total_current,
           CAST(AVG(S.i_a_current) AS DECIMAL(18, 3)) AS site_i_a_current,
           CAST(AVG(S.i_b_current) AS DECIMAL(18, 3)) AS site_i_b_current,
           CAST(AVG(S.i_c_current) AS DECIMAL(18, 3)) AS site_i_c_current,
           CAST(AVG(L.instant_power) AS DECIMAL(18, 3)) AS load_instant_power,
           CAST(AVG(L.instant_reactive_power) AS DECIMAL(18, 3)) AS load_instant_reactive_power,
           CAST(AVG(L.instant_apparent_power) AS DECIMAL(18, 3)) AS load_instant_apparent_power,
           CAST(AVG(L.frequency) AS DECIMAL(18, 3)) AS load_frequency,
           CAST(AVG(L.energy_exported) AS DECIMAL(18, 3)) AS load_energy_exported,
           CAST(AVG(L.energy_imported) AS DECIMAL(18, 3)) AS load_energy_imported,
           CAST(AVG(L.instant_average_voltage) AS DECIMAL(18, 3)) AS load_instant_average_voltage,
           CAST(AVG(L.instant_total_current) AS DECIMAL(18, 3)) AS load_instant_total_current,
           CAST(AVG(L.i_a_current) AS DECIMAL(18, 3)) AS load_i_a_current,
           CAST(AVG(L.i_b_current) AS DECIMAL(18, 3)) AS load_i_b_current,
           CAST(AVG(L.i_c_current) AS DECIMAL(18, 3)) AS load_i_c_current,
           CAST(AVG(PV.instant_power) AS DECIMAL(18, 3)) AS solar_instant_power,
           CAST(AVG(PV.instant_reactive_power) AS DECIMAL(18, 3)) AS solar_instant_reactive_power,
           CAST(AVG(PV.instant_apparent_power) AS DECIMAL(18, 3)) AS solar_instant_apparent_power,
           CAST(AVG(PV.frequency) AS DECIMAL(18, 3)) AS solar_frequency,
           CAST(AVG(PV.energy_exported) AS DECIMAL(18, 3)) AS solar_energy_exported,
           CAST(AVG(PV.energy_imported) AS DECIMAL(18, 3)) AS solar_energy_imported,
           CAST(AVG(PV.instant_average_voltage) AS DECIMAL(18, 3)) AS solar_instant_average_voltage,
           CAST(AVG(PV.instant_total_current) AS DECIMAL(18, 3)) AS solar_instant_total_current,
           CAST(AVG(PV.i_a_current) AS DECIMAL(18, 3)) AS solar_i_a_current,
           CAST(AVG(PV.i_b_current) AS DECIMAL(18, 3)) AS solar_i_b_current,
           CAST(AVG(PV.i_c_current) AS DECIMAL(18, 3)) AS solar_i_c_current,
           CAST(AVG(SOC.state_of_charge) AS DECIMAL(18, 3)) AS soc_state_of_charge,
		   CAST((SELECT ISNULL(PeriodPower, 0) FROM dbo.fnGetDailyPVForecast(@StartDate) WHERE PeriodStartTime = @StartDate) AS DECIMAL(18, 3)) AS solcast_forecast
    FROM FiveMinObs AS O
      INNER LOOP JOIN battery AS B
            ON B.ObservationID = O.ObservationID
        INNER LOOP JOIN site AS S
            ON S.ObservationID = O.ObservationID
        INNER LOOP JOIN load AS L
            ON L.ObservationID = O.ObservationID
        INNER LOOP JOIN solar AS PV
            ON PV.ObservationID = O.ObservationID
        INNER LOOP JOIN soc AS SOC
            ON SOC.ObservationID = O.ObservationID
END;
GO
/****** Object:  StoredProcedure [dbo].[spGetDailyPVForecast]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spGetDailyPVForecast](@TargetDate DATE = NULL)
AS
BEGIN
	/*

	Testing
	-------

	EXEC spGetDailyPVForecast '2018-03-29 09:20:01'
	EXEC spGetDailyPVForecast '2018-03-30 13:20:00'
	EXEC spGetDailyPVForecast '2018-03-31 17:19:59'

	*/
	SELECT PeriodStartTime, PeriodPower FROM dbo.fnGetDailyPVForecast(@TargetDate)
	ORDER BY PeriodStartTime
END
GO
/****** Object:  StoredProcedure [dbo].[spGetDailyPVForecastPVOutput]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spGetDailyPVForecastPVOutput](@TargetDate DATE = NULL)
AS
BEGIN
	/*

	Testing
	-------

	EXEC spGetDailyPVForecastPVOutput '2018-03-29 09:20:01'
	EXEC spGetDailyPVForecastPVOutput '2018-03-30 13:20:00'
	EXEC spGetDailyPVForecastPVOutput '2018-03-31 17:19:59'
	EXEC spGetDailyPVForecastPVOutput

	*/
	SELECT CONVERT(VARCHAR(16), PeriodStartTime, 20) + ',' + CAST(PeriodPower AS VARCHAR(30)) AS PVOutputLiveLoad
	FROM dbo.fnGetDailyPVForecast(@TargetDate)
	ORDER BY PeriodStartTime
END
GO
/****** Object:  StoredProcedure [dbo].[spStoreForecast]    Script Date: 31/03/2018 6:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spStoreForecast](@JSON AS VARCHAR(MAX))
AS
BEGIN
/* Testing

EXEC spStoreForecast 
'
{"forecasts":[{"period_end":"2018-03-24T05:00:00.0000000Z","period":"PT30M","pv_estimate":2091.27407126992},{"period_end":"2018-03-24T05:30:00.0000000Z","period":"PT30M","pv_estimate":2017.03142480386},{"period_end":"2018-03-24T06:00:00.0000000Z","period":"PT30M","pv_estimate":1665.46732640755},{"period_end":"2018-03-24T06:30:00.0000000Z","period":"PT30M","pv_estimate":1324.49372924903},{"period_end":"2018-03-24T07:00:00.0000000Z","period":"PT30M","pv_estimate":935.36731944305},{"period_end":"2018-03-24T07:30:00.0000000Z","period":"PT30M","pv_estimate":485.779462559317},{"period_end":"2018-03-24T08:00:00.0000000Z","period":"PT30M","pv_estimate":281.078475569055},{"period_end":"2018-03-24T08:30:00.0000000Z","period":"PT30M","pv_estimate":26.5903601977163},{"period_end":"2018-03-24T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-24T21:00:00.0000000Z","period":"PT30M","pv_estimate":32.6340951788018},{"period_end":"2018-03-24T21:30:00.0000000Z","period":"PT30M","pv_estimate":159.045189307651},{"period_end":"2018-03-24T22:00:00.0000000Z","period":"PT30M","pv_estimate":459.679872886949},{"period_end":"2018-03-24T22:30:00.0000000Z","period":"PT30M","pv_estimate":798.887356152977},{"period_end":"2018-03-24T23:00:00.0000000Z","period":"PT30M","pv_estimate":1130.41551857551},{"period_end":"2018-03-24T23:30:00.0000000Z","period":"PT30M","pv_estimate":1402.41725225258},{"period_end":"2018-03-25T00:00:00.0000000Z","period":"PT30M","pv_estimate":1585.55381208078},{"period_end":"2018-03-25T00:30:00.0000000Z","period":"PT30M","pv_estimate":1688.00893630105},{"period_end":"2018-03-25T01:00:00.0000000Z","period":"PT30M","pv_estimate":1730.28563890304},{"period_end":"2018-03-25T01:30:00.0000000Z","period":"PT30M","pv_estimate":1743.54376109418},{"period_end":"2018-03-25T02:00:00.0000000Z","period":"PT30M","pv_estimate":1759.52802317689},{"period_end":"2018-03-25T02:30:00.0000000Z","period":"PT30M","pv_estimate":1813.42027253419},{"period_end":"2018-03-25T03:00:00.0000000Z","period":"PT30M","pv_estimate":1918.66039274158},{"period_end":"2018-03-25T03:30:00.0000000Z","period":"PT30M","pv_estimate":2090.61325347045},{"period_end":"2018-03-25T04:00:00.0000000Z","period":"PT30M","pv_estimate":2212.21312212334},{"period_end":"2018-03-25T04:30:00.0000000Z","period":"PT30M","pv_estimate":2208.48083175854},{"period_end":"2018-03-25T05:00:00.0000000Z","period":"PT30M","pv_estimate":2082.44983027987},{"period_end":"2018-03-25T05:30:00.0000000Z","period":"PT30M","pv_estimate":1851.84641643737},{"period_end":"2018-03-25T06:00:00.0000000Z","period":"PT30M","pv_estimate":1557.07896637765},{"period_end":"2018-03-25T06:30:00.0000000Z","period":"PT30M","pv_estimate":1213.45357288189},{"period_end":"2018-03-25T07:00:00.0000000Z","period":"PT30M","pv_estimate":862.725821272989},{"period_end":"2018-03-25T07:30:00.0000000Z","period":"PT30M","pv_estimate":522.427520172026},{"period_end":"2018-03-25T08:00:00.0000000Z","period":"PT30M","pv_estimate":195.923642687004},{"period_end":"2018-03-25T08:30:00.0000000Z","period":"PT30M","pv_estimate":33.0666858538863},{"period_end":"2018-03-25T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-25T21:00:00.0000000Z","period":"PT30M","pv_estimate":38.5185120954362},{"period_end":"2018-03-25T21:30:00.0000000Z","period":"PT30M","pv_estimate":163.272706214733},{"period_end":"2018-03-25T22:00:00.0000000Z","period":"PT30M","pv_estimate":399.258468687338},{"period_end":"2018-03-25T22:30:00.0000000Z","period":"PT30M","pv_estimate":598.560591462029},{"period_end":"2018-03-25T23:00:00.0000000Z","period":"PT30M","pv_estimate":756.595237658578},{"period_end":"2018-03-25T23:30:00.0000000Z","period":"PT30M","pv_estimate":821.99078353121},{"period_end":"2018-03-26T00:00:00.0000000Z","period":"PT30M","pv_estimate":839.374455089513},{"period_end":"2018-03-26T00:30:00.0000000Z","period":"PT30M","pv_estimate":791.888882931576},{"period_end":"2018-03-26T01:00:00.0000000Z","period":"PT30M","pv_estimate":735.427523835133},{"period_end":"2018-03-26T01:30:00.0000000Z","period":"PT30M","pv_estimate":704.932499621284},{"period_end":"2018-03-26T02:00:00.0000000Z","period":"PT30M","pv_estimate":713.651936668171},{"period_end":"2018-03-26T02:30:00.0000000Z","period":"PT30M","pv_estimate":735.427667345919},{"period_end":"2018-03-26T03:00:00.0000000Z","period":"PT30M","pv_estimate":735.992171519217},{"period_end":"2018-03-26T03:30:00.0000000Z","period":"PT30M","pv_estimate":800.841165295785},{"period_end":"2018-03-26T04:00:00.0000000Z","period":"PT30M","pv_estimate":865.397281257707},{"period_end":"2018-03-26T04:30:00.0000000Z","period":"PT30M","pv_estimate":933.931209225734},{"period_end":"2018-03-26T05:00:00.0000000Z","period":"PT30M","pv_estimate":1028.32693940518},{"period_end":"2018-03-26T05:30:00.0000000Z","period":"PT30M","pv_estimate":1104.73758890562},{"period_end":"2018-03-26T06:00:00.0000000Z","period":"PT30M","pv_estimate":1107.24374960427},{"period_end":"2018-03-26T06:30:00.0000000Z","period":"PT30M","pv_estimate":1016.52510866034},{"period_end":"2018-03-26T07:00:00.0000000Z","period":"PT30M","pv_estimate":812.720443992869},{"period_end":"2018-03-26T07:30:00.0000000Z","period":"PT30M","pv_estimate":547.252747519784},{"period_end":"2018-03-26T08:00:00.0000000Z","period":"PT30M","pv_estimate":219.453584187992},{"period_end":"2018-03-26T08:30:00.0000000Z","period":"PT30M","pv_estimate":35.9806619476546},{"period_end":"2018-03-26T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-26T21:00:00.0000000Z","period":"PT30M","pv_estimate":45.7053296027843},{"period_end":"2018-03-26T21:30:00.0000000Z","period":"PT30M","pv_estimate":225.848483728123},{"period_end":"2018-03-26T22:00:00.0000000Z","period":"PT30M","pv_estimate":560.092646898423},{"period_end":"2018-03-26T22:30:00.0000000Z","period":"PT30M","pv_estimate":905.834492997616},{"period_end":"2018-03-26T23:00:00.0000000Z","period":"PT30M","pv_estimate":1219.96533256641},{"period_end":"2018-03-26T23:30:00.0000000Z","period":"PT30M","pv_estimate":1460.44226688596},{"period_end":"2018-03-27T00:00:00.0000000Z","period":"PT30M","pv_estimate":1644.49492260507},{"period_end":"2018-03-27T00:30:00.0000000Z","period":"PT30M","pv_estimate":1739.15680754455},{"period_end":"2018-03-27T01:00:00.0000000Z","period":"PT30M","pv_estimate":1793.88561137039},{"period_end":"2018-03-27T01:30:00.0000000Z","period":"PT30M","pv_estimate":1846.10950923822},{"period_end":"2018-03-27T02:00:00.0000000Z","period":"PT30M","pv_estimate":1882.18127553002},{"period_end":"2018-03-27T02:30:00.0000000Z","period":"PT30M","pv_estimate":1900.9902110703},{"period_end":"2018-03-27T03:00:00.0000000Z","period":"PT30M","pv_estimate":1885.37813912552},{"period_end":"2018-03-27T03:30:00.0000000Z","period":"PT30M","pv_estimate":1848.84824547422},{"period_end":"2018-03-27T04:00:00.0000000Z","period":"PT30M","pv_estimate":1782.26744531519},{"period_end":"2018-03-27T04:30:00.0000000Z","period":"PT30M","pv_estimate":1680.43547258173},{"period_end":"2018-03-27T05:00:00.0000000Z","period":"PT30M","pv_estimate":1537.8826656101},{"period_end":"2018-03-27T05:30:00.0000000Z","period":"PT30M","pv_estimate":1365.80834297784},{"period_end":"2018-03-27T06:00:00.0000000Z","period":"PT30M","pv_estimate":1182.7343263351},{"period_end":"2018-03-27T06:30:00.0000000Z","period":"PT30M","pv_estimate":963.460941263338},{"period_end":"2018-03-27T07:00:00.0000000Z","period":"PT30M","pv_estimate":724.106429530145},{"period_end":"2018-03-27T07:30:00.0000000Z","period":"PT30M","pv_estimate":459.014463766011},{"period_end":"2018-03-27T08:00:00.0000000Z","period":"PT30M","pv_estimate":180.244736943412},{"period_end":"2018-03-27T08:30:00.0000000Z","period":"PT30M","pv_estimate":32.6826718078022},{"period_end":"2018-03-27T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-27T21:00:00.0000000Z","period":"PT30M","pv_estimate":42.8179905341712},{"period_end":"2018-03-27T21:30:00.0000000Z","period":"PT30M","pv_estimate":230.655814708386},{"period_end":"2018-03-27T22:00:00.0000000Z","period":"PT30M","pv_estimate":555.850231239145},{"period_end":"2018-03-27T22:30:00.0000000Z","period":"PT30M","pv_estimate":884.953824154128},{"period_end":"2018-03-27T23:00:00.0000000Z","period":"PT30M","pv_estimate":1212.05362926791},{"period_end":"2018-03-27T23:30:00.0000000Z","period":"PT30M","pv_estimate":1490.24055432336},{"period_end":"2018-03-28T00:00:00.0000000Z","period":"PT30M","pv_estimate":1753.00372639417},{"period_end":"2018-03-28T00:30:00.0000000Z","period":"PT30M","pv_estimate":1951.01402790148},{"period_end":"2018-03-28T01:00:00.0000000Z","period":"PT30M","pv_estimate":2104.99378636349},{"period_end":"2018-03-28T01:30:00.0000000Z","period":"PT30M","pv_estimate":2232.06964419612},{"period_end":"2018-03-28T02:00:00.0000000Z","period":"PT30M","pv_estimate":2312.12193563288},{"period_end":"2018-03-28T02:30:00.0000000Z","period":"PT30M","pv_estimate":2343.16748570367},{"period_end":"2018-03-28T03:00:00.0000000Z","period":"PT30M","pv_estimate":2312.08630039092},{"period_end":"2018-03-28T03:30:00.0000000Z","period":"PT30M","pv_estimate":2277.60702440777},{"period_end":"2018-03-28T04:00:00.0000000Z","period":"PT30M","pv_estimate":2194.93461594975},{"period_end":"2018-03-28T04:30:00.0000000Z","period":"PT30M","pv_estimate":2079.61812281768},{"period_end":"2018-03-28T05:00:00.0000000Z","period":"PT30M","pv_estimate":1917.66267367407},{"period_end":"2018-03-28T05:30:00.0000000Z","period":"PT30M","pv_estimate":1727.98574077124},{"period_end":"2018-03-28T06:00:00.0000000Z","period":"PT30M","pv_estimate":1494.01557785437},{"period_end":"2018-03-28T06:30:00.0000000Z","period":"PT30M","pv_estimate":1224.61765723607},{"period_end":"2018-03-28T07:00:00.0000000Z","period":"PT30M","pv_estimate":911.026665614719},{"period_end":"2018-03-28T07:30:00.0000000Z","period":"PT30M","pv_estimate":577.002624059701},{"period_end":"2018-03-28T08:00:00.0000000Z","period":"PT30M","pv_estimate":225.422770078063},{"period_end":"2018-03-28T08:30:00.0000000Z","period":"PT30M","pv_estimate":33.8641807916314},{"period_end":"2018-03-28T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-28T21:00:00.0000000Z","period":"PT30M","pv_estimate":43.8758789194277},{"period_end":"2018-03-28T21:30:00.0000000Z","period":"PT30M","pv_estimate":264.178323818535},{"period_end":"2018-03-28T22:00:00.0000000Z","period":"PT30M","pv_estimate":621.592402932291},{"period_end":"2018-03-28T22:30:00.0000000Z","period":"PT30M","pv_estimate":1001.57259523243},{"period_end":"2018-03-28T23:00:00.0000000Z","period":"PT30M","pv_estimate":1348.4291340248},{"period_end":"2018-03-28T23:30:00.0000000Z","period":"PT30M","pv_estimate":1667.54732501223},{"period_end":"2018-03-29T00:00:00.0000000Z","period":"PT30M","pv_estimate":1952.76709532529},{"period_end":"2018-03-29T00:30:00.0000000Z","period":"PT30M","pv_estimate":2181.99334220457},{"period_end":"2018-03-29T01:00:00.0000000Z","period":"PT30M","pv_estimate":2338.18163520967},{"period_end":"2018-03-29T01:30:00.0000000Z","period":"PT30M","pv_estimate":2475.79454882162},{"period_end":"2018-03-29T02:00:00.0000000Z","period":"PT30M","pv_estimate":2539.08919458428},{"period_end":"2018-03-29T02:30:00.0000000Z","period":"PT30M","pv_estimate":2579.0910131334},{"period_end":"2018-03-29T03:00:00.0000000Z","period":"PT30M","pv_estimate":2558.67774678851},{"period_end":"2018-03-29T03:30:00.0000000Z","period":"PT30M","pv_estimate":2515.98428262939},{"period_end":"2018-03-29T04:00:00.0000000Z","period":"PT30M","pv_estimate":2429.02983728847},{"period_end":"2018-03-29T04:30:00.0000000Z","period":"PT30M","pv_estimate":2299.60145977118},{"period_end":"2018-03-29T05:00:00.0000000Z","period":"PT30M","pv_estimate":2117.27339264132},{"period_end":"2018-03-29T05:30:00.0000000Z","period":"PT30M","pv_estimate":1897.7516282308},{"period_end":"2018-03-29T06:00:00.0000000Z","period":"PT30M","pv_estimate":1641.397634364},{"period_end":"2018-03-29T06:30:00.0000000Z","period":"PT30M","pv_estimate":1341.56048024517},{"period_end":"2018-03-29T07:00:00.0000000Z","period":"PT30M","pv_estimate":988.981661574491},{"period_end":"2018-03-29T07:30:00.0000000Z","period":"PT30M","pv_estimate":629.506480322735},{"period_end":"2018-03-29T08:00:00.0000000Z","period":"PT30M","pv_estimate":260.696369012796},{"period_end":"2018-03-29T08:30:00.0000000Z","period":"PT30M","pv_estimate":36.362259327923},{"period_end":"2018-03-29T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-29T21:00:00.0000000Z","period":"PT30M","pv_estimate":48.9500713175377},{"period_end":"2018-03-29T21:30:00.0000000Z","period":"PT30M","pv_estimate":262.280527476533},{"period_end":"2018-03-29T22:00:00.0000000Z","period":"PT30M","pv_estimate":602.742474867846},{"period_end":"2018-03-29T22:30:00.0000000Z","period":"PT30M","pv_estimate":921.475627993027},{"period_end":"2018-03-29T23:00:00.0000000Z","period":"PT30M","pv_estimate":1205.01457580815},{"period_end":"2018-03-29T23:30:00.0000000Z","period":"PT30M","pv_estimate":1433.54203107205},{"period_end":"2018-03-30T00:00:00.0000000Z","period":"PT30M","pv_estimate":1622.3921731116},{"period_end":"2018-03-30T00:30:00.0000000Z","period":"PT30M","pv_estimate":1755.81114828857},{"period_end":"2018-03-30T01:00:00.0000000Z","period":"PT30M","pv_estimate":1842.72806827647},{"period_end":"2018-03-30T01:30:00.0000000Z","period":"PT30M","pv_estimate":1880.92937312208},{"period_end":"2018-03-30T02:00:00.0000000Z","period":"PT30M","pv_estimate":1882.18071871465},{"period_end":"2018-03-30T02:30:00.0000000Z","period":"PT30M","pv_estimate":1859.41075232177},{"period_end":"2018-03-30T03:00:00.0000000Z","period":"PT30M","pv_estimate":1812.44254937117},{"period_end":"2018-03-30T03:30:00.0000000Z","period":"PT30M","pv_estimate":1788.74752965352},{"period_end":"2018-03-30T04:00:00.0000000Z","period":"PT30M","pv_estimate":1764.23232726718},{"period_end":"2018-03-30T04:30:00.0000000Z","period":"PT30M","pv_estimate":1727.64289888359},{"period_end":"2018-03-30T05:00:00.0000000Z","period":"PT30M","pv_estimate":1657.09361527963},{"period_end":"2018-03-30T05:30:00.0000000Z","period":"PT30M","pv_estimate":1542.18992175612},{"period_end":"2018-03-30T06:00:00.0000000Z","period":"PT30M","pv_estimate":1387.86356919464},{"period_end":"2018-03-30T06:30:00.0000000Z","period":"PT30M","pv_estimate":1155.77450422932},{"period_end":"2018-03-30T07:00:00.0000000Z","period":"PT30M","pv_estimate":886.187029197394},{"period_end":"2018-03-30T07:30:00.0000000Z","period":"PT30M","pv_estimate":563.861738626363},{"period_end":"2018-03-30T08:00:00.0000000Z","period":"PT30M","pv_estimate":224.449658637631},{"period_end":"2018-03-30T08:30:00.0000000Z","period":"PT30M","pv_estimate":35.5405178813654},{"period_end":"2018-03-30T09:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T09:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T10:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T10:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T11:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T11:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T12:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T12:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T13:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T13:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T14:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T14:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T15:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T15:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T16:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T16:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T17:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T17:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T18:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T18:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T19:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T19:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T20:00:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T20:30:00.0000000Z","period":"PT30M","pv_estimate":0},{"period_end":"2018-03-30T21:00:00.0000000Z","period":"PT30M","pv_estimate":50.8462941802986},{"period_end":"2018-03-30T21:30:00.0000000Z","period":"PT30M","pv_estimate":278.637031946895},{"period_end":"2018-03-30T22:00:00.0000000Z","period":"PT30M","pv_estimate":632.288246469998},{"period_end":"2018-03-30T22:30:00.0000000Z","period":"PT30M","pv_estimate":977.328255127551},{"period_end":"2018-03-30T23:00:00.0000000Z","period":"PT30M","pv_estimate":1283.03525509064},{"period_end":"2018-03-30T23:30:00.0000000Z","period":"PT30M","pv_estimate":1564.09198280666},{"period_end":"2018-03-31T00:00:00.0000000Z","period":"PT30M","pv_estimate":1827.40819932906},{"period_end":"2018-03-31T00:30:00.0000000Z","period":"PT30M","pv_estimate":2013.9839684136},{"period_end":"2018-03-31T01:00:00.0000000Z","period":"PT30M","pv_estimate":2160.44973186406},{"period_end":"2018-03-31T01:30:00.0000000Z","period":"PT30M","pv_estimate":2265.56017714493},{"period_end":"2018-03-31T02:00:00.0000000Z","period":"PT30M","pv_estimate":2311.79481737219},{"period_end":"2018-03-31T02:30:00.0000000Z","period":"PT30M","pv_estimate":2320.57678642946},{"period_end":"2018-03-31T03:00:00.0000000Z","period":"PT30M","pv_estimate":2285.21761456222},{"period_end":"2018-03-31T03:30:00.0000000Z","period":"PT30M","pv_estimate":2230.24566424375},{"period_end":"2018-03-31T04:00:00.0000000Z","period":"PT30M","pv_estimate":2155.17424199627},{"period_end":"2018-03-31T04:30:00.0000000Z","period":"PT30M","pv_estimate":2050.45530867748}]}
'

*/
	WITH RawForecastPeriods AS (
								SELECT		DateTimeString
								,			PowerEstimate
								FROM		OPENJSON(@JSON,'$.forecasts') AS Forecasts
								CROSS APPLY OPENJSON(Forecasts.Value) 
												WITH	(	DateTimeString CHAR(28) '$.period_end'
														,	PowerEstimate NUMERIC(17,13) '$.pv_estimate'
														) AS ForecastPeriods
								)
	MERGE forecasts AS ExistingForecasts
	USING (	SELECT	CAST(CONVERT(DATETIMEOFFSET, DateTimeString) AS DATETIME) AS EstimateDateTimeUTC
			,		CAST(CONVERT(DATETIMEOFFSET, DateTimeString) AT TIME ZONE 'AUS Eastern Standard Time' AS DATETIME) as EstimateDateTimeLocal
			,		PowerEstimate / 2 as EnergyEstimate
			FROM	RawForecastPeriods) AS LatestForecasts
	ON LatestForecasts.EstimateDateTimeUTC = ExistingForecasts.EstimateDateTimeUTC
	WHEN MATCHED THEN UPDATE SET EnergyEstimate = LatestForecasts.EnergyEstimate
	WHEN NOT MATCHED
		THEN	INSERT	(	EstimateDateTimeUTC
						,	EstimateDateTimeLocal
						,	EnergyEstimate
						,	OriginalEnergyEstimate
						)
				VALUES	(	LatestForecasts.EstimateDateTimeUTC
						,	LatestForecasts.EstimateDateTimeLocal
						,	LatestForecasts.EnergyEstimate
						,	LatestForecasts.EnergyEstimate
						);
END
GO
USE [master]
GO
ALTER DATABASE [PWHistory] SET  READ_WRITE 
GO
