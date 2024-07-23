/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv, wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_Match3rdResultSel]
	@MatchId INT
AS

/*
	Created: 20210813@Razor
	Task: Alpha Result Report - Get match result detail
	DB: DBAGE.bodb02
	Original: Acc_BetList_Match3rdResultSel
	Revisions:
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20240723@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
*/

BEGIN
	SET NOCOUNT ON

	IF EXISTS (SELECT 1 FROM dbo.match3rd WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.league3rdid,
			m.match3rdid,
			m.MatchCode,
			CASE WHEN m.SportType IN (175) THEN m.endtime ELSE m.StartTime END AS EventDate,
			m.HtHomeScore,
			m.HtAwayScore,
			m.FinalHomeScore,
			m.FinalAwayScore,
			m.HomeId,
			m.AwayId,
			m.eventstatus
		FROM dbo.match3rd AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId
				AND 1 = CASE
							WHEN m.SportType IN (147, 175) AND m.eventstatus = 'completed' THEN 1
							WHEN m.SportType = 147 AND m.eventstatus IN ('Suspend', 'Running') AND (hthomescore IS NOT NULL OR htawayscore IS NOT NULL) THEN 1
						ELSE 0 END

		SELECT
			MatchID,
			GameResult
		FROM dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE MatchID = @MatchId 
			AND SettlementStatusID > 0
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.match3rd14 WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.league3rdid,
			m.match3rdid,
			m.MatchCode,
			CASE WHEN m.SportType IN (175) THEN m.endtime ELSE m.StartTime END AS EventDate,
			m.HtHomeScore,
			m.HtAwayScore,
			m.FinalHomeScore,
			m.FinalAwayScore,
			m.HomeId,
			m.AwayId,
			m.eventstatus
		FROM dbo.match3rd14 AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId
				AND 1 = CASE
					WHEN m.SportType IN (147, 175) AND m.eventstatus = 'completed' THEN 1
					WHEN m.SportType = 147 AND m.eventstatus IN ('Suspend') AND (hthomescore IS NOT NULL OR htawayscore IS NOT NULL) THEN 1
				ELSE 0 END

		SELECT
			MatchID,
			GameResult
		FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
		WHERE MatchID = @MatchId 
			AND SettlementStatusID > 0
	END
	ELSE
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.league3rdid,
			m.match3rdid,
			m.MatchCode,
			CASE WHEN m.SportType IN (175) THEN m.endtime ELSE m.StartTime END AS EventDate,
			m.HtHomeScore,
			m.HtAwayScore,
			m.FinalHomeScore,
			m.FinalAwayScore,
			m.HomeId,
			m.AwayId,
			m.eventstatus
		FROM DBARC.bodb_Archive.dbo.match3rd_bk AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId
			AND 1 = CASE
				WHEN m.SportType IN (147, 175) AND m.eventstatus = 'completed' THEN 1
				WHEN m.SportType = 147 AND m.eventstatus IN ('Suspend') AND (hthomescore IS NOT NULL OR htawayscore IS NOT NULL) THEN 1
			ELSE 0 END

		SELECT
			MatchID,
			GameResult
		FROM DBARC.bodb_Archive.dbo.ResultDetail3rd_bk WITH (NOLOCK)
		WHERE MatchID = @MatchId 
			AND SettlementStatusID > 0
	END
END
GO
