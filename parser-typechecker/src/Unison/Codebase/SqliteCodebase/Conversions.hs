module Unison.Codebase.SqliteCodebase.Conversions where

import qualified Data.ByteString.Short as SBS
import Data.Text (Text)
import qualified U.Codebase.Decl as V2.Decl
import qualified U.Codebase.Kind as V2.Kind
import qualified U.Codebase.Reference as V2
import qualified U.Codebase.Reference as V2.Reference
import qualified U.Codebase.Referent as V2
import qualified U.Codebase.Sqlite.Symbol as V2
import qualified U.Codebase.Term as V2.Term
import qualified U.Codebase.Type as V2.Type
import qualified U.Core.ABT as V2.ABT
import qualified U.Util.Hash as V2
import qualified U.Util.Hash as V2.Hash
import qualified Unison.ABT as V1.ABT
import qualified Unison.ConstructorType as CT
import Unison.Hash (Hash)
import qualified Unison.Hash as V1
import qualified Unison.Kind as V1.Kind
import Unison.Parser (Ann)
import qualified Unison.Parser as Ann
import qualified Unison.Pattern as P
import qualified Unison.Reference as V1
import qualified Unison.Reference as V1.Reference
import qualified Unison.Referent as V1
import qualified Unison.Symbol as V1
import qualified Unison.Term as V1.Term
import qualified Unison.Type as V1.Type
import qualified Unison.Var as Var

decltype2to1 :: V2.Decl.DeclType -> CT.ConstructorType
decltype2to1 = \case
  V2.Decl.Data -> CT.Data
  V2.Decl.Effect -> CT.Effect

decltype1to2 :: CT.ConstructorType -> V2.Decl.DeclType
decltype1to2 = \case
   CT.Data -> V2.Decl.Data
   CT.Effect -> V2.Decl.Effect

term2to1 :: forall m. Monad m => Hash -> (Hash -> m V1.Reference.Size) -> (V2.Reference -> m CT.ConstructorType) -> V2.Term.Term V2.Symbol -> m (V1.Term.Term V1.Symbol Ann)
term2to1 h lookupSize lookupCT tm =
  V1.ABT.transformM (termF2to1 h lookupSize lookupCT)
    . V1.ABT.vmap symbol2to1
    . V1.ABT.amap (const Ann.External)
    $ abt2to1 tm

symbol2to1 :: V2.Symbol -> V1.Symbol
symbol2to1 (V2.Symbol i t) = V1.Symbol i (Var.User t)

symbol1to2 :: V1.Symbol -> V2.Symbol
symbol1to2 (V1.Symbol i (Var.User t)) = V2.Symbol i t
symbol1to2 x = error $ "unimplemented: symbol1to2 " ++ show x

abt2to1 :: Functor f => V2.ABT.Term f v a -> V1.ABT.Term f v a
abt2to1 (V2.ABT.Term fv a out) = V1.ABT.Term fv a (go out)
  where
    go = \case
      V2.ABT.Cycle body -> V1.ABT.Cycle (abt2to1 body)
      V2.ABT.Abs v body -> V1.ABT.Abs v (abt2to1 body)
      V2.ABT.Var v -> V1.ABT.Var v
      V2.ABT.Tm tm -> V1.ABT.Tm (abt2to1 <$> tm)

abt1to2 :: Functor f => V1.ABT.Term f v a -> V2.ABT.Term f v a
abt1to2 (V1.ABT.Term fv a out) = V2.ABT.Term fv a (go out)
  where
    go = \case
      V1.ABT.Cycle body -> V2.ABT.Cycle (abt1to2 body)
      V1.ABT.Abs v body -> V2.ABT.Abs v (abt1to2 body)
      V1.ABT.Var v -> V2.ABT.Var v
      V1.ABT.Tm tm -> V2.ABT.Tm (abt1to2 <$> tm)

rreference2to1 :: Applicative m => Hash -> (Hash -> m V1.Reference.Size) -> V2.Reference' Text (Maybe V2.Hash) -> m V1.Reference
rreference2to1 h lookupSize = \case
  V2.ReferenceBuiltin t -> pure $ V1.Reference.Builtin t
  V2.ReferenceDerived i -> V1.Reference.DerivedId <$> rreferenceid2to1 h lookupSize i

rreference1to2 :: Hash -> V1.Reference -> V2.Reference' Text (Maybe V2.Hash)
rreference1to2 h = \case
  V1.Reference.Builtin t -> V2.ReferenceBuiltin t
  V1.Reference.DerivedId i -> V2.ReferenceDerived (rreferenceid1to2 h i)

rreferenceid2to1 :: Functor m => Hash -> (Hash -> m V1.Reference.Size) -> V2.Reference.Id' (Maybe V2.Hash) -> m V1.Reference.Id
rreferenceid2to1 h lookupSize (V2.Reference.Id oh i) =
  V1.Reference.Id h' i <$> lookupSize h'
  where
    h' = maybe h hash2to1 oh

rreferenceid1to2 :: Hash -> V1.Reference.Id -> V2.Reference.Id' (Maybe V2.Hash)
rreferenceid1to2 h (V1.Reference.Id h' i _n) = V2.Reference.Id oh i
  where
    oh = if h == h' then Nothing else Just (hash1to2 h')

hash1to2 :: Hash -> V2.Hash
hash1to2 (V1.Hash bs) = V2.Hash.Hash (SBS.toShort bs)

reference2to1 :: Applicative m => (Hash -> m V1.Reference.Size) -> V2.Reference -> m V1.Reference
reference2to1 lookupSize = \case
  V2.ReferenceBuiltin t -> pure $ V1.Reference.Builtin t
  V2.ReferenceDerived i -> V1.Reference.DerivedId <$> referenceid2to1 lookupSize i

reference1to2 :: V1.Reference -> V2.Reference
reference1to2 = \case
  V1.Reference.Builtin t -> V2.ReferenceBuiltin t
  V1.Reference.DerivedId i -> V2.ReferenceDerived (referenceid1to2 i)

referenceid1to2 :: V1.Reference.Id -> V2.Reference.Id
referenceid1to2 (V1.Reference.Id h i _n) = V2.Reference.Id (hash1to2 h) i

referenceid2to1 :: Functor m => (Hash -> m V1.Reference.Size) -> V2.Reference.Id -> m V1.Reference.Id
referenceid2to1 lookupSize (V2.Reference.Id h i) =
  V1.Reference.Id sh i <$> lookupSize sh
  where
    sh = hash2to1 h

rreferent2to1 :: Applicative m => Hash -> (Hash -> m V1.Reference.Size) -> (V2.Reference -> m CT.ConstructorType) -> V2.ReferentH -> m V1.Referent
rreferent2to1 h lookupSize lookupCT = \case
  V2.Ref r -> V1.Ref <$> rreference2to1 h lookupSize r
  V2.Con r i -> V1.Con <$> reference2to1 lookupSize r <*> pure (fromIntegral i) <*> lookupCT r

rreferent1to2 :: Hash -> V1.Referent -> V2.ReferentH
rreferent1to2 h = \case
  V1.Ref r -> V2.Ref (rreference1to2 h r)
  V1.Con r i _ct -> V2.Con (reference1to2 r) (fromIntegral i)

hash2to1 :: V2.Hash.Hash -> Hash
hash2to1 (V2.Hash.Hash sbs) = V1.Hash (SBS.fromShort sbs)

ttype2to1 :: Monad m => (Hash -> m V1.Reference.Size) -> V2.Term.Type V2.Symbol -> m (V1.Type.Type V1.Symbol Ann)
ttype2to1 lookupSize = type2to1' (reference2to1 lookupSize)

dtype2to1 :: Monad m => Hash -> (Hash -> m V1.Reference.Size) -> V2.Decl.Type V2.Symbol -> m (V1.Type.Type V1.Symbol Ann)
dtype2to1 h lookupSize = type2to1' (rreference2to1 h lookupSize)

type2to1' :: Monad m => (r -> m V1.Reference) -> V2.Type.TypeR r V2.Symbol -> m (V1.Type.Type V1.Symbol Ann)
type2to1' convertRef =
  V1.ABT.transformM (typeF2to1 convertRef)
    . V1.ABT.vmap symbol2to1
    . V1.ABT.amap (const Ann.External)
    . abt2to1
  where
    typeF2to1 :: Applicative m => (r -> m V1.Reference) -> V2.Type.F' r a -> m (V1.Type.F a)
    typeF2to1 convertRef = \case
      V2.Type.Ref r -> V1.Type.Ref <$> convertRef r
      V2.Type.Arrow i o -> pure $ V1.Type.Arrow i o
      V2.Type.Ann a k -> pure $ V1.Type.Ann a (convertKind k)
      V2.Type.App f x -> pure $ V1.Type.App f x
      V2.Type.Effect e b -> pure $ V1.Type.Effect e b
      V2.Type.Effects as -> pure $ V1.Type.Effects as
      V2.Type.Forall a -> pure $ V1.Type.Forall a
      V2.Type.IntroOuter a -> pure $ V1.Type.IntroOuter a
      where
        convertKind = \case
          V2.Kind.Star -> V1.Kind.Star
          V2.Kind.Arrow i o -> V1.Kind.Arrow (convertKind i) (convertKind o)

type1to2' :: (V1.Reference -> r) -> V1.Type.Type V1.Symbol a -> V2.Type.TypeR r V2.Symbol
type1to2' convertRef =
  V2.ABT.transform (typeF1to2' convertRef)
  . V2.ABT.vmap symbol1to2
  . V2.ABT.amap (const ())
  . abt1to2

typeF1to2' :: (V1.Reference -> r) -> V1.Type.F a -> V2.Type.F' r a
typeF1to2' convertRef = \case
  V1.Type.Ref r -> V2.Type.Ref (convertRef r)
  V1.Type.Arrow i o -> V2.Type.Arrow i o
  V1.Type.Ann a k -> V2.Type.Ann a (convertKind k)
  V1.Type.App f x -> V2.Type.App f x
  V1.Type.Effect e b -> V2.Type.Effect e b
  V1.Type.Effects as -> V2.Type.Effects as
  V1.Type.Forall a -> V2.Type.Forall a
  V1.Type.IntroOuter a -> V2.Type.IntroOuter a
  where
    convertKind = \case
      V1.Kind.Star -> V2.Kind.Star
      V1.Kind.Arrow i o -> V2.Kind.Arrow (convertKind i) (convertKind o)


termF2to1 :: forall m a. Monad m => Hash -> (Hash -> m V1.Reference.Size) -> (V2.Reference -> m CT.ConstructorType) -> V2.Term.F V2.Symbol a -> m (V1.Term.F V1.Symbol Ann Ann a)
termF2to1 h lookupSize lookupCT = go
  where
    go :: V2.Term.F V2.Symbol a -> m (V1.Term.F V1.Symbol Ann Ann a)
    go = \case
      V2.Term.Int i -> pure $ V1.Term.Int i
      V2.Term.Nat n -> pure $ V1.Term.Nat n
      V2.Term.Float d -> pure $ V1.Term.Float d
      V2.Term.Boolean b -> pure $ V1.Term.Boolean b
      V2.Term.Text t -> pure $ V1.Term.Text t
      V2.Term.Char c -> pure $ V1.Term.Char c
      V2.Term.Ref r -> V1.Term.Ref <$> rreference2to1 h lookupSize r
      V2.Term.Constructor r i ->
        V1.Term.Constructor <$> reference2to1 lookupSize r <*> pure (fromIntegral i)
      V2.Term.Request r i ->
        V1.Term.Request <$> reference2to1 lookupSize r <*> pure (fromIntegral i)
      V2.Term.Handle a a4 -> pure $ V1.Term.Handle a a4
      V2.Term.App a a4 -> pure $ V1.Term.App a a4
      V2.Term.Ann a t2 -> V1.Term.Ann a <$> ttype2to1 lookupSize t2
      V2.Term.Sequence sa -> pure $ V1.Term.Sequence sa
      V2.Term.If a a4 a5 -> pure $ V1.Term.If a a4 a5
      V2.Term.And a a4 -> pure $ V1.Term.And a a4
      V2.Term.Or a a4 -> pure $ V1.Term.Or a a4
      V2.Term.Lam a -> pure $ V1.Term.Lam a
      V2.Term.LetRec as a -> pure $ V1.Term.LetRec False as a
      V2.Term.Let a a4 -> pure $ V1.Term.Let False a a4
      V2.Term.Match a cases -> V1.Term.Match a <$> traverse goCase cases
      V2.Term.TermLink rr -> V1.Term.TermLink <$> rreferent2to1 h lookupSize lookupCT rr
      V2.Term.TypeLink r -> V1.Term.TypeLink <$> reference2to1 lookupSize r
    goCase = \case
      V2.Term.MatchCase pat cond body ->
        V1.Term.MatchCase <$> (goPat pat) <*> pure cond <*> pure body
    goPat = \case
      V2.Term.PUnbound -> pure $ P.Unbound a
      V2.Term.PVar -> pure $ P.Var a
      V2.Term.PBoolean b -> pure $ P.Boolean a b
      V2.Term.PInt i -> pure $ P.Int a i
      V2.Term.PNat n -> pure $ P.Nat a n
      V2.Term.PFloat d -> pure $ P.Float a d
      V2.Term.PText t -> pure $ P.Text a t
      V2.Term.PChar c -> pure $ P.Char a c
      V2.Term.PConstructor r i ps ->
        P.Constructor a <$> reference2to1 lookupSize r <*> pure i <*> (traverse goPat ps)
      V2.Term.PAs p -> P.As a <$> goPat p
      V2.Term.PEffectPure p -> P.EffectPure a <$> goPat p
      V2.Term.PEffectBind r i ps p -> P.EffectBind a <$> reference2to1 lookupSize r <*> pure i <*> traverse goPat ps <*> goPat p
      V2.Term.PSequenceLiteral ps -> P.SequenceLiteral a <$> traverse goPat ps
      V2.Term.PSequenceOp p1 op p2 -> P.SequenceOp a <$> goPat p1 <*> pure (goOp op) <*> goPat p2
    goOp = \case
      V2.Term.PCons -> P.Cons
      V2.Term.PSnoc -> P.Snoc
      V2.Term.PConcat -> P.Concat
    a = Ann.External
