/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_RaceSelByLeague]
	@EventDate		DATETIME,
	@MoveBetsDay	DATETIME,
	@LeagueId		INT,
	@SportType		SMALLINT	= 0
AS

/*
	Task: Alpha Result Report - Virtual Sports (VS7)
	DB: DBAGE.bodb02
	Original: Age_Result_RaceSelByLeague
	Revisions:
		- 20250401@Razor: Support VS7 [Redmine: #221173]
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @Race TABLE (
		EventId			INT,
		LeagueID		INT,
		VendorMatchId	VARCHAR(50),
		Distance		VARCHAR(10),
		EventTime		DATETIME,
		EventStatus		NVARCHAR(50),
		BetStatus		VARCHAR(10)
	)

	IF @EventDate > @MoveBetsDay		-- bettrans range
	BEGIN
		INSERT INTO @Race
		SELECT DISTINCT
			r.EventID,
			r.LeagueID,
			r.VendorMatchId,
			r.Distance,
			r.EventTime,
			r.EventStatus,
			r.BetStatus
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
			r.Distance,
			r.EventTime,
			r.EventStatus,
			r.BetStatus
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
