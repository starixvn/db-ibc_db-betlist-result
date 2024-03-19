/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_HRSelMatchResult2]
	@MatchId	INT
AS

/*
	Created: Dom@20141202
	Task: Get Result of Virtual Horse Racing
	DB: DBACC.bodb02

	Revisions:
		- 20180105@Kos: Remove param @Bettype and @BetId [#Redmine: 88775]
					- Remove Horse Racing code
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE (
		HorseNo		VARCHAR(50),
		KickOffTime	DATETIME,
		RaceName	VARCHAR(50),
		Place		TINYINT,
		SportType	INT,
		HorseId		INT,
		Odds		SMALLMONEY,
		PlaceOdds	SMALLMONEY,
		MeetingId	INT,
		OddsStatus	VARCHAR(10),
		IsFavor		VARCHAR(10),
		IsSCR		BIT,
		FOddsStatus	VARCHAR(10)
	)

	IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchId)
	BEGIN
		INSERT INTO @Data
		SELECT
			o.RacerNum AS HorseNo,
			r.EventTime,
			NULL AS RaceName,
			o.Placing AS Place,
			r.SportType,
			o.RacerID AS HorseId,
			o.WinOdds AS Odds,
			o.PlaceOdds,
			'' AS MeetingId,
			o.EventStatus AS Status,
			o.IsFavor,
			'' AS IsSCR,
			'' AS FOddsStatus
		FROM dbo.VSOutright AS o WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
	END
	ELSE IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE EventID = @MatchId)
	BEGIN
		INSERT INTO @Data
		SELECT
			o.RacerNum AS HorseNo,
			r.EventTime,
			NULL AS RaceName,
			o.Placing AS Place,
			r.SportType,
			o.RacerID AS HorseId,
			o.WinOdds AS Odds,
			o.PlaceOdds,
			'' AS MeetingId,
			o.EventStatus AS Status,
			o.IsFavor,
			'' AS IsSCR,
			'' AS FOddsStatus
		FROM dbo.VSOutright14 AS o WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
	END
	ELSE
	BEGIN
		INSERT INTO @Data
		SELECT
			o.RacerNum AS HorseNo,
			r.EventTime,
			NULL AS RaceName,
			o.Placing AS Place,
			r.SportType,
			o.RacerID AS HorseId,
			o.WinOdds AS Odds,
			o.placeodds,
			'' AS MeetingId,
			o.EventStatus AS Status,
			o.IsFavor,
			'' AS IsSCR,
			'' AS FOddsStatus
		FROM bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
	END

	IF EXISTS (SELECT 1 FROM @Data WHERE SportType IN (181, 182, 183, 184, 185))
	BEGIN
		SELECT
			KickOffTime,
			COUNT(Place) AS rc
		INTO #DataSUMVHR
		FROM @Data
		GROUP BY KickOffTime

		SELECT
			d.HorseNo,
			d.KickOffTime,
			d.RaceName,
			d.Place,
			d.SportType,
			d.HorseId,
			CASE d.SportType * d.Place	--check whether the sport is Virtual Cycling & get the place
				WHEN 0 THEN 0		-- 0 * 185
				WHEN 370 THEN 0		-- 2 * 185
				WHEN 555 THEN 0		-- 3 * 185
				WHEN 740 THEN 0		-- 4 * 185
				ELSE d.Odds
			END AS Odds,
			CASE d.SportType	--check whether the sport is Virtual Speedway or not
				WHEN 183 THEN 0
				ELSE d.PlaceOdds
			END AS PlaceOdds,
			d.MeetingId,
			d.OddsStatus,
			d.IsFavor,
			d.IsSCR,
			d.FOddsStatus,
			'' AS TF,
			'' AS SCR,
			d2.rc AS [RowCount]
		FROm @Data AS d
			INNER JOIN #DataSumVHR AS d2 ON d.KickoffTime = d2.kickofftime 
		WHERE (d.Place < 5 AND d.SportType <> 183)
			OR (d.Place < 2 AND d.SportType = 183)
		ORDER BY
			d.MeetingId ASC,
			d.KickOffTime ASC,
			d.Place ASC

		DROP TABLE #DataSumVHR
	END
	ELSE
	BEGIN
		SELECT * FROM @Data
	END
END
GO
