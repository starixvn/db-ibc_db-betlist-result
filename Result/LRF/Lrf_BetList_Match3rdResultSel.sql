/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Match3rdResultSel]
	@MatchId INT
AS

/*
	Created: 20210914@Kos
	Task: LAP/LRF Result Report - Get match 3rd result detail
	DB: DBEXT.bodb02

	Revisions:
		- 20210914@Kos: Support Bitcoin [Redmine: #160160]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Detail TABLE (
		Match3rdId	INT,
		GameResult	VARCHAR(50)
	)

	IF EXISTS (SELECT 1 FROM dbo.Match3rd WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			SportType,
			BetStatus,
			League3rdId,
			Match3rdId,
			EndTime AS EventDate,
			EventStatus
		FROM dbo.Match3rd WITH (NOLOCK)
		WHERE Match3rdId = @MatchId AND EventStatus IN ('completed')

		INSERT INTO @Detail
		SELECT
			MatchID,
			GameResult
		FROM dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE MatchID = @MatchId AND SettlementStatusID > 0
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.Match3rd14 WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			SportType,
			BetStatus,
			League3rdId,
			Match3rdId,
			EndTime AS EventDate,
			EventStatus
		FROM dbo.Match3rd14 AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId

		INSERT INTO @Detail
		SELECT
			MatchID,
			GameResult
		FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
		WHERE MatchID = @MatchId AND SettlementStatusID > 0
	END
	ELSE
	BEGIN
		SELECT
			SportType,
			BetStatus,
			League3rdId,
			Match3rdId,
			EndTime AS EventDate,
			EventStatus
		FROM DBARC.bodb_Archive.dbo.match3rd_bk WITH (NOLOCK)
		WHERE Match3rdId = @MatchId

		INSERT INTO @Detail
		SELECT
			MatchID,
			GameResult
		FROM DBARC.bodb_Archive.dbo.ResultDetail3rd_bk WITH (NOLOCK)
		WHERE MatchID = @MatchId AND SettlementStatusID > 0
	END

	SELECT * FROM @Detail
END
GO
