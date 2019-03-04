/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_TicketResult_Racing]
	@MatchId	INT
AS
 
/*
	Created: Dom@20141202
	Task: Get ticket result of a Racing ticket
	DB: DBAGE.bodb02
	Original: Age_BetList_SelMatchResult2

	Revisions:
		- 20190304@Kos: Create new [Redmine: 109230]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE (
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
		FOddsStatus	VARCHAR(10))

	-- Virtual Horse Racing
	IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchId)
	BEGIN
		INSERT INTO @Result
		SELECT
			o.RacerNum AS HorseNo,
			r.EventTime,
			NULL AS RaceName,
			o.Placing AS place,
			r.SportType,
			o.RacerID AS HorseId,
			o.WinOdds AS odds,
			o.placeodds,
			'' AS MeetingId,
			o.EventStatus AS status,
			o.IsFavor,
			'' AS IsSCR,
			'' AS FOddsStatus
		FROM dbo.VSOutright AS o WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
		ORDER BY o.Placing
	END
	ELSE IF EXISTS (SELECT TOP(1) 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE EventID = @MatchId)
	BEGIN
		INSERT INTO @Result
		SELECT
			o.RacerNum AS HorseNo,
			r.EventTime,
			NULL AS RaceName,
			o.Placing AS place,
			r.SportType,
			o.RacerID AS HorseId,
			o.WinOdds AS odds,
			o.PlaceOdds,
			'' AS MeetingId,
			o.EventStatus AS status,
			o.IsFavor,
			'' AS IsSCR,
			'' AS FOddsStatus
		FROM dbo.VSOutright14 AS o WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE o.EventID = @MatchId AND (ISNULL(o.Placing, 0) <> 0)
		ORDER BY o.Placing
	END
	ELSE
	BEGIN
		INSERT INTO @Result
		SELECT
			o.RacerNum AS HorseNo,
			r.EventTime,
			NULL AS RaceName,
			o.Placing AS place,
			r.SportType,
			o.RacerID AS HorseId,
			o.WinOdds AS Odds,
			o.placeodds,
			'' AS MeetingId,
			o.EventStatus AS status,
			o.IsFavor,
			'' AS IsSCR,
			'' AS FOddsStatus
		FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE o.EventID = @MatchId AND (ISNULL(o.placing, 0) <> 0)
		ORDER BY o.placing
	END

	IF EXISTS (SELECT 1 FROM @Result WHERE SportType IN (181, 182, 183, 184, 185))
	BEGIN 
		SELECT KickOffTime,
			COUNT(Place) AS rc
		INTO #DataSUMVHR
		FROM @Result
		GROUP BY KickOffTime

		SELECT
			d.HorseNo,
			d.KickOffTime,
			d.RaceName,
			d.Place,
			d.SportType,
			d.HorseId,
			CASE d.SportType * d.Place --check whether the sport is Virtual Cycling & get the place
				WHEN 0 THEN 0		-- 0 * 185
				WHEN 370 THEN 0		-- 2 * 185
				WHEN 555 THEN 0		-- 3 * 185
				WHEN 740 THEN 0		-- 4 * 185
				ELSE d.Odds
			END AS Odds,
			CASE d.SportType --check whether the sport is Virtual Speedway or not
				WHEN 183 THEN 0
				ELSE d.PlaceOdds
			END AS PlaceOdds,
			d.MeetingId,
			d.OddsStatus,
			d.IsFavor,
			d.IsSCR,
			d.FOddsStatus,
			'' TF,
			'' SCR,
			d2.rc AS [RowCount]
		FROm @Result AS d
			INNER JOIN #DataSumVHR AS d2 ON d.KickOffTime = d2.kickofftime
		WHERE (d.Place < 5 AND d.SportType <> 183)
			OR (d.Place < 2 AND d.SportType = 183)
		ORDER BY d.MeetingId,
			d.KickOffTime,
			d.Place

		DROP TABLE #DataSumVHR
	END
	ELSE
	BEGIN
		SELECT * FROM @Result
	END
END
GO


GRANT	EXECUTE	ON	CS_TicketResult_Racing	TO	bodbDownlineNet
GO
GRANT	EXECUTE	ON	CS_TicketResult_Racing	TO	bodbDownlineNetView
GO
