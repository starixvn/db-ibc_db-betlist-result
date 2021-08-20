/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

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
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Detail TABLE (
		Match3rdId				INT,
		GameResult			VARCHAR(50)
	)

	IF EXISTS (SELECT 1 FROM dbo.match3rd WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.league3rdid,
			m.match3rdid,
			m.endtime AS EventDate,
			m.eventstatus
		FROM dbo.match3rd AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId
			AND m.eventstatus IN ('completed')

		INSERT INTO @Detail
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
			m.endtime AS EventDate,
			m.eventstatus
		FROM dbo.match3rd14 AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId

		INSERT INTO @Detail
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
			m.endtime AS EventDate,
			m.eventstatus
		FROM DBARC.bodb_Archive.dbo.match3rd_bk AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId

		INSERT INTO @Detail
		SELECT
			MatchID,
			GameResult
		FROM DBARC.bodb_Archive.dbo.ResultDetail3rd_bk WITH (NOLOCK)
		WHERE MatchID = @MatchId 
			AND SettlementStatusID > 0
	END
	SELECT * FROM @Detail
END
GO
