/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_TicketResult_Race]
	@EventId		INT,
	@EventDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: 20240919@Kos
	Task: LRF - Ticket Result - Virtual Sports - Race
	DB: DBACC.bodb02

	Revisions:
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
*/

BEGIN
	SET NOCOUNT ON

	IF @EventDate > @MoveBetsDay		-- bettrans range
	BEGIN
		SELECT
			EventID,
			LeagueID,
			VendorMatchId,
			EventTime,
			EventStatus,
			BetStatus,
			Distance
		FROM dbo.VSRaceInfo WITH (NOLOCK)
		WHERE EventID = @EventId

		SELECT
			Orid,
			EventID,
			Placing,
			Lane,
			RacerID
		FROM dbo.VSOutright WITH (NOLOCK)
		WHERE EventID = @EventId AND Placing < 4
	END
	ELSE IF @EventDate BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
	BEGIN
		SELECT
			EventID,
			LeagueID,
			VendorMatchId,
			EventTime,
			EventStatus,
			BetStatus,
			Distance
		FROM dbo.VSRaceInfo14 WITH (NOLOCK)
		WHERE EventID = @EventId

		SELECT
			Orid,
			EventID,
			Placing,
			Lane,
			RacerID
		FROM dbo.VSOutright14 WITH (NOLOCK)
		WHERE EventID = @EventId AND Placing < 4
	END
	ELSE
	BEGIN
		SELECT
			EventID,
			LeagueID,
			VendorMatchId,
			EventTime,
			EventStatus,
			BetStatus,
			Distance
		FROM bodb_Archive.dbo.VSRaceInfo_bk WITH (NOLOCK)
		WHERE EventID = @EventId

		SELECT
			Orid,
			EventID,
			Placing,
			Lane,
			RacerID
		FROM bodb_Archive.dbo.VSOutright_bk WITH (NOLOCK)
		WHERE EventID = @EventId AND Placing < 4
	END
END
GO
