/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_RaceSelByLeague]
	@EventDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LeagueId		INT,
	@SportType		SMALLINT
AS

/*
	Created: 20240919@Kos
	Task: LRF - Result Report - Virtual Sports - Select Race By League
	DB: DBEXT.bodb02

	Revisions:
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Race TABLE (
		EventId			INT,
		LeagueID		INT,
		VendorMatchId	VARCHAR(50),
		EventTime		DATETIME,
		EventStatus		NVARCHAR(50),
		BetStatus		VARCHAR(10),
		Distance		VARCHAR(10)
	)

	IF @EventDate > @MoveBetsDay		-- bettrans range
	BEGIN
		INSERT INTO @Race
		SELECT DISTINCT
			r.EventID,
			r.LeagueID,
			r.VendorMatchId,
			r.EventTime,
			r.EventStatus,
			r.BetStatus,
			r.Distance
		FROM dbo.VSRaceInfo AS r WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON o.EventID = r.EventID
		WHERE o.EventDate = @EventDate
			AND r.SportType = @SportType
			AND @LeagueId IN (0, r.LeagueID)
			AND r.EventStatus = 'Completed'

		SELECT * FROM @Race
		ORDER BY EventTime DESC

		SELECT
			o.Orid,
			o.EventID,
			o.Placing,
			o.Lane,
			o.RacerID
		FROM dbo.VSOutright AS o WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM @Race WHERE EventId = o.EventID)
			AND o.Placing < 4
	END
	ELSE		-- bettrans14 range
	BEGIN
		INSERT INTO @Race
		SELECT DISTINCT
			r.EventID,
			r.LeagueID,
			r.VendorMatchId,
			r.EventTime,
			r.EventStatus,
			r.BetStatus,
			r.Distance
		FROM dbo.VSRaceInfo14 AS r WITH (NOLOCK)
			INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON o.EventID = r.EventID
		WHERE o.EventDate = @EventDate
			AND r.SportType = @SportType
			AND @LeagueId IN (0, r.LeagueID)
			AND r.EventStatus = 'Completed'

		SELECT * FROM @Race
		ORDER BY EventTime DESC

		SELECT
			o.Orid,
			o.EventID,
			o.Placing,
			o.Lane,
			o.RacerID
		FROM dbo.VSOutright14 AS o WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM @Race WHERE EventId = o.EventID)
			AND o.Placing < 4
	END
END
GO
