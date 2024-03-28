/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_VSRaceSelByMeeting]
	@FromDate		DATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LeagueId		INT			= 0,
	@SportType		SMALLINT	= 181,
	@isShowAll		BIT			= 1 -- 1: Show All; 0: is NOT show Test
AS

/*
	Created: 20141201@Dom
	DB: DBAGE.bodb02
	Original: Age_Result_RaceSelByMeeting
	Revisions:
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
					- Add new param @MoveBetsDay SMALLDATETIME
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data (
		MeetingId	INT,
		EventDate	DATETIME,
		KickOffTime	DATETIME,
		Lcolor		NVARCHAR(50),
		Racename	VARCHAR(20),
		Place		INT,
		HorseNo		VARCHAR(20),
		HorseId		INT,
		Odds		MONEY,
		PlaceOdds	MONEY,
		Status		VARCHAR(20),
		IsFavor		VARCHAR(20),
		IsSCR		BIT,
		FOddsStatus	VARCHAR(20),
		SportType	INT)

	SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

	IF @FromDate > @MoveBetsDay
	BEGIN
		INSERT INTO #Data
		SELECT
			vsr.leagueid AS MeetingId,
			vso.EventDate,
			vsr.EventTime AS KickOffTime,
			vso.Colours AS Lcolor,
			NULL AS Racename, 
			CASE
				WHEN CONVERT(INT, vso.placing) = 0 THEN 5
				ELSE ISNULL(CONVERT(INT, vso.placing), 5)
			END AS Place,
			CONVERT(VARCHAR(20),vso.RacerNum) AS HorseNo,
			vso.RacerID AS HorseId,
			vso.Winodds AS Odds,
			vso.PlaceOdds,
			vsr.EventStatus AS Status,
			CONVERT(VARCHAR(20),vso.IsFavor) AS IsFavor,
			NULL AS IsSCR,
			'' AS FOddsStatus,
			l.sporttype
		FROM
			dbo.VSOutright AS vso WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
			INNER JOIN dbo.HRCode AS c WITH (NOLOCK) ON c.CodeID = vso.RacerID
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON vsr.leagueid = l.leagueid
		WHERE
			vso.EventDate = @FromDate
			AND l.leagueid = CASE WHEN @LeagueId = 0 THEN l.leagueid ELSE @LeagueId END 
			AND vso.Placing < 5
			AND ISNULL(vso.Placing, 0) <> 0
			AND vsr.SportType = @SportType
			AND vsr.EventStatus ='completed'
	END
	ELSE
	BEGIN
		INSERT INTO #Data
		SELECT
			vsr.leagueid AS MeetingId,
			vso.EventDate,
			vsr.EventTime AS KickOffTime,
			vso.Colours AS Lcolor,
			NULL AS Racename, 
			CASE
				WHEN CONVERT(INT, vso.placing) = 0 THEN 5
				ELSE ISNULL(CONVERT(INT, vso.placing), 5)
			END AS Place,
			CONVERT(VARCHAR(20),vso.RacerNum) AS HorseNo,
			vso.RacerID AS HorseId,
			vso.Winodds AS Odds,
			vso.PlaceOdds,
			vsr.EventStatus AS Status,
			CONVERT(VARCHAR(20),vso.IsFavor) AS IsFavor,
			NULL AS IsSCR,
			'' AS FOddsStatus,
			l.sporttype
		FROM
			dbo.VSOutright14 AS vso WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo14 AS vsr WITH (NOLOCK) ON vso.EventID = vsr.EventID
			INNER JOIN dbo.HRCode AS c WITH (NOLOCK) ON c.CodeID = vso.RacerID
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON vsr.leagueid = l.leagueid
		WHERE
			vso.EventDate = @FromDate
			AND l.leagueid = CASE WHEN @LeagueId = 0 THEN l.leagueid ELSE @LeagueId END 
			AND vso.Placing < 5
			AND ISNULL(vso.Placing, 0) <> 0
			AND vsr.SportType = @SportType
			AND vsr.EventStatus ='completed'
	END

	SELECT
		KickOffTime,
		COUNT(Place) rc
	INTO #DataSUMVHR
	FROM #Data
	GROUP BY KickOffTime

	SELECT
		d.MeetingId,
		d.EventDate,
		d.KickOffTime,
		d.Lcolor,
		d.Racename,
		d.Place,
		d.HorseNo,
		d.HorseId,
		CASE d.SportType * d.Place --check whether the sport is Virtual Cycling & get the place
			WHEN 0 THEN 0   --0*185
			WHEN 370 THEN 0	-- 2* 185
			WHEN 555 THEN 0 -- 3*185
			WHEN 740 THEN 0 -- 4*185
			ELSE d.Odds
		END AS odds,
		CASE d.SportType --check whether the sport is Virtual Speedway or not
			WHEN 183 THEN 0
			ELSE d.PlaceOdds
		END AS PlaceOdds,
		d.Status,
		d.IsFavor,
		d.IsSCR,
		d.FOddsStatus,
		'' TF,
		'' SCR,
		d2.rc AS [RowCount]
	FROm #Data d
		INNER JOIN #DataSumVHR d2 ON d.kickofftime = d2.kickofftime 
	WHERE (d.place < 5 AND d.sporttype <> 183)
		OR (d.place < 2 AND d.sporttype = 183)
	ORDER BY
		d.meetingid ASC,
		d.kickofftime ASC,
		d.place ASC

	DROP TABLE #DataSumVHR 
	DROP TABLE #Data
END
GO
