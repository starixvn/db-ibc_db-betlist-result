/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv, wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelRaceResult]
	@EventId	INT,
	@EventDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created:
	Task: Alpha - Ticket Result - Virtual Sports - Race
	DB: DBAGE.bodb02

	Revisions:
		- 20240920@Razor: Support VS2 - Racing sports [Redmine: #211092]
*/

BEGIN
	SET NOCOUNT ON

	IF @EventDate > @MoveBetsDay		-- bettrans range
	BEGIN
		SELECT
			EventID,
			LeagueID,
			VendorMatchId,
			Distance,
			EventTime,
			EventStatus,
			BetStatus
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
			Distance,
			EventTime,
			EventStatus,
			BetStatus
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
			Distance,
			EventTime,
			EventStatus,
			BetStatus
		FROM DBARC.bodb_Archive.dbo.VSRaceInfo_bk WITH (NOLOCK)
		WHERE EventID = @EventId

		SELECT
			Orid,
			EventID,
			Placing,
			Lane,
			RacerID
		FROM DBARC.bodb_Archive.dbo.VSOutright_bk WITH (NOLOCK)
		WHERE EventID = @EventId AND Placing < 4
	END
END